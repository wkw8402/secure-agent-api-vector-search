-- Create vector index for fast similarity search
-- Using ivfflat (ScaNN) with 100 lists for optimal performance
CREATE INDEX ON customer_records_data
USING ivfflat (abstract_embeddings vector_l2_ops)
WITH (lists = 100);

