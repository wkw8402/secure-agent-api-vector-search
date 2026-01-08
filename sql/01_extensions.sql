-- Enable vector extension for storing embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant permission to execute the embedding function
GRANT EXECUTE ON FUNCTION embedding TO postgres;

