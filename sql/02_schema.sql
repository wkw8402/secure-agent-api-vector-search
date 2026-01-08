-- Create table for customer records with vector embeddings column
CREATE TABLE customer_records_data (
    id VARCHAR(25),
    type VARCHAR(25),
    number VARCHAR(20),
    country VARCHAR(2),
    date VARCHAR(20),
    abstract VARCHAR(300000),
    title VARCHAR(100000),
    kind VARCHAR(6),
    num_claims BIGINT,
    filename VARCHAR(100),
    withdrawn BIGINT,
    abstract_embeddings vector(768)
);

