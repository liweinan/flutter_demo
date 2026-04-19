CREATE TABLE IF NOT EXISTS demo_greeting (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);

INSERT INTO demo_greeting (message)
SELECT 'Hello from PostgreSQL'
WHERE NOT EXISTS (SELECT 1 FROM demo_greeting LIMIT 1);
