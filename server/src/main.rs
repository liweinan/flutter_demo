use axum::{
    extract::State,
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Serialize;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio_postgres::NoTls;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
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

fn static_ui_root() -> PathBuf {
    std::env::var("STATIC_UI_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/srv/ui"))
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

    let api = Router::new()
        .route("/health", get(health))
        .route("/db-version", get(db_version))
        .route("/greeting", get(greeting))
        .with_state(state);

    let ui_root = static_ui_root();
    let app = if ui_root.exists() {
        tracing::info!("Serving React UI from {:?}", ui_root);
        Router::new()
            .merge(api)
            .nest_service(
                "/ui",
                ServeDir::new(ui_root).append_index_html_on_directories(true),
            )
            .layer(cors)
            .layer(TraceLayer::new_for_http())
    } else {
        tracing::warn!(
            "STATIC_UI_ROOT {:?} 不存在，跳过 /ui（本地可先 npm run build）",
            ui_root
        );
        Router::new().merge(api).layer(cors).layer(TraceLayer::new_for_http())
    };

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
