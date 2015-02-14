set search_path = :data_product, public;
set client_encoding = 'LATIN1';

select sql_create_tmp_geoheader(true);
--Imports states passed in through psql
select sql_import_geoheader(true, :states);
select sql_create_import_tables(true);
--Imports margins of error and estimates for states 
--passed in through psql and all sequences
select sql_import_sequences(true, :states);
select sql_create_geoheader(true);
select sql_geoheader_comments(true);

--For table-based data store:
select sql_store_by_tables(true);
select sql_view_estimate_stored_by_tables(true);
select sql_view_moe_stored_by_tables(true);
--Copies all data from tmp_geoheader to geoheader
select sql_parse_tmp_geoheader(true);
--Copies all estimates and margins of error to sequence tables
select sql_insert_into_tables(true);