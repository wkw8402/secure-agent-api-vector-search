-- Test the embedding function
SELECT embedding('text-embedding-005', 'AlloyDB is a managed, cloud-hosted SQL database service.');

-- Generate embeddings for all abstracts
UPDATE customer_records_data
SET abstract_embeddings = embedding('text-embedding-005', abstract);

