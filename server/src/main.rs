use axum::{
    extract::State,
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Serialize;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio_postgres::NoTls;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

#[derive(Clone)]
struct AppState {
    database_url: String,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
}

#[derive(Serialize)]
struct DbVersionResponse {
    version: String,
}

#[derive(Serialize)]
struct GreetingResponse {
    message: String,
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    let database_url = std::env::var("DATABASE_URL")
        .map_err(|_| "DATABASE_URL must be set")?;
    let bind_addr =
        std::env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());

    let state = Arc::new(AppState { database_url });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/health", get(health))
        .route("/db-version", get(db_version))
        .route("/greeting", get(greeting))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = TcpListener::bind(&bind_addr).await?;
    tracing::info!("listening on http://{}", bind_addr);
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse { status: "ok" })
}

async fn db_version(
    State(state): State<Arc<AppState>>,
) -> Result<Json<DbVersionResponse>, (StatusCode, Json<ErrorBody>)> {
    let (client, connection) = tokio_postgres::connect(&state.database_url, NoTls)
        .await
        .map_err(|e| {
            tracing::error!("db connect: {e}");
            (
                StatusCode::BAD_GATEWAY,
                Json(ErrorBody {
                    error: "database connection failed".to_string(),
                }),
            )
        })?;

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            tracing::error!("db connection task: {e}");
        }
    });

    let row = client
        .query_one("SELECT version() AS version", &[])
        .await
        .map_err(|e| {
            tracing::error!("db query: {e}");
            (
                StatusCode::BAD_GATEWAY,
                Json(ErrorBody {
                    error: "database query failed".to_string(),
                }),
            )
        })?;

    let version: String = row.get("version");
    Ok(Json(DbVersionResponse { version }))
}

async fn greeting(
    State(state): State<Arc<AppState>>,
) -> Result<Json<GreetingResponse>, (StatusCode, Json<ErrorBody>)> {
    let (client, connection) = tokio_postgres::connect(&state.database_url, NoTls)
        .await
        .map_err(|e| {
            tracing::error!("db connect: {e}");
            (
                StatusCode::BAD_GATEWAY,
                Json(ErrorBody {
                    error: "database connection failed".to_string(),
                }),
            )
        })?;

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            tracing::error!("db connection task: {e}");
        }
    });

    let row = client
        .query_one(
            "SELECT message FROM demo_greeting ORDER BY id ASC LIMIT 1",
            &[],
        )
        .await
        .map_err(|e| {
            tracing::error!("db query: {e}");
            (
                StatusCode::BAD_GATEWAY,
                Json(ErrorBody {
                    error: "database query failed".to_string(),
                }),
            )
        })?;

    let message: String = row.get("message");
    Ok(Json(GreetingResponse { message }))
}
