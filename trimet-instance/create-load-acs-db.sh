# Set postgres parameters
pg_host=localhost
pg_user=postgres
pg_schema=acs2013_5yr #schema name must match census convention
pg_dbase=census

# Prompt the user to enter their postgres password, 'PGPASSWORD' is an environment
# variable and will be applied to pgsql tools automatically when it is exported
export PGPASSWORD
echo "Enter PostGreSQL Password:"
read -s PGPASSWORD

# Set project workspaces, the data directory must be somewhere that postgres can
# read from with the 'COPY' command
data_dir="C:/Program Files/PostgreSQL/9.3/data/census"
code_dir="G:/PUBLIC/GIS_Projects/Census_Analysis/Census-Postgres/census-postgres"
schema_dir="${data_dir}/${pg_schema}"
mkdir -p "$schema_dir"

census_url="http://www2.census.gov/${pg_schema}/summaryfile"
states="ARRAY['or', 'wa']"

# The years that comprise the timeframe covered by the given ACS data is needed for
# the various elements, this can be derived from the Census abbreviation/schema name
yr=${pg_schema:3:4}
len=${pg_schema:8:1}
b_yr=$(expr ${yr} - ${len} + 1)

downloadPrepareData()
{
	# Download ACS data from the Census Bureau's website, set a the directory structure
	# need for the upload scripts and unzip the downloaded files

	tract_block_group="Tracts_Block_Groups_Only"
	other_geography="All_Geographies_Not_Tracts_Block_Groups"
	declare -a geog_array=("$tract_block_group" "$other_geography")
	
	for i in "${geog_array[@]}"
	do
		mkdir -p "${schema_dir}/${i}"
	done

	data_url="${census_url}/${b_yr}-${yr}_ACSSF_By_State_All_Tables"	
	
	declare -a state_array=("Oregon" "Washington")
	for i in "${state_array[@]}"
	do
		for j in "${geog_array[@]}"
		do 
			file_name="${i}_${j}.zip"
			full_path="${schema_dir}/${j}/${file_name}"
			
			echo "wget ${data_url}/${file_name} -O $full_path"
			wget "${data_url}/${file_name}" -O "$full_path"
			
			echo "unzip -q $full_path -d ${schema_dir}/${j}"
			unzip -q "$full_path" -d "${schema_dir}/${j}"
		done
	done
}

createPostGisDb()
{
	# Create new Db (drop if already exists)
	dropdb -h $pg_host -U $pg_user --if-exists -i $pg_dbase
	createdb -O $pg_user -h $pg_host -U $pg_user $pg_dbase
	
	# spatially enable the Db
	postgis_cmd="CREATE EXTENSION postgis;"
	psql -d $pg_dbase -h $pg_host -U $pg_user -c "$postgis_cmd"
}

runMetaScripts()
{
	# Run scripts that will create pl/PGSQL functions that will be used to create
	# and load the ACS schema

	meta1="Support Functions and Tables.sql"
	meta2="Staging Tables and Data Import Functions.sql"
	meta3="Geoheader.sql"
	meta4="Data Store Table-Based.sql"
	meta_path="${code_dir}/meta-scripts"

	declare -a meta_scripts=("$meta1" "$meta2" "$meta3" "$meta4")
	for i in "${meta_scripts[@]}"
	do
		psql -h $pg_host -U $pg_user -d $pg_dbase -f "${meta_path}/${i}"
	done
}

setUploadRootDataProduct()
{
	# Indicate the location of the root directory that contains 
	# that ACS/Census Data
	set_root_cmd="SELECT set_census_upload_root('${data_dir}');"
	echo "psql -h $pg_host -U $pg_user -d $pg_dbase -c $set_root_cmd"
	psql -h $pg_host -U $pg_user -d $pg_dbase -c "$set_root_cmd"

	set_product_cmd="SELECT set_data_product(${yr}, ${len});"
	echo "psql -h $pg_host -U $pg_user -d $pg_dbase -c $set_product_cmd"
	psql -h $pg_host -U $pg_user -d $pg_dbase -c "$set_product_cmd"
}

createSchema()
{
	# Create schema that will hold the given year and year-span (e.g. 5 year)
	# ACS data
	schema_cmd="CREATE SCHEMA $pg_schema;"
	echo "psql -h $pg_host -U $pg_user -d $pg_dbase -c $schema_cmd"
	psql -h $pg_host -U $pg_user -d $pg_dbase -c "$schema_cmd"
}

setupDataDictTables()
{
	# Download the data dictionary from the Census website and save it in
	# in the location that subsequent scripts are expecting
	d_dict="Sequence_Number_and_Table_Number_Lookup.txt"
	echo "wget ${census_url}/${d_dict} -O ${schema_dir}/${d_dict}"
	wget ${census_url}/${d_dict} -O "${schema_dir}/${d_dict}"

	sed -i='original' -r 's/,\s+/,/g' "${schema_dir}/${d_dict}"

	d_dict_script="${code_dir}/${pg_schema}/ACS ${yr} Data Dictionary.sql"
	psql -h $pg_host -U $pg_user -d $pg_dbase -f "$d_dict_script"
}

runDataFunctions()
{
	# Execute scripts that will build schemas and populate tables and views with
	# the ACS data from the selected product

	data_script="${code_dir}/trimet-instance/execute_data_functions.sql"
	echo "psql -h $pg_host -U $pg_user -d $pg_dbase -v states=${states} -v data_product=${pg_schema} -f "$data_script""
	psql -e -h $pg_host -U $pg_user -d $pg_dbase -v states="${states}" \
		-v data_product="${pg_schema}" -f "$data_script" > cen-pg.log
}

#downloadPrepareData;
createPostGisDb;
runMetaScripts;
setUploadRootDataProduct;
createSchema;
setupDataDictTables;
runDataFunctions;