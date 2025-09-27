CREATE TABLE fuel_economy_stg (
    model_year NVARCHAR(4) NULL, -- to be populated by ADF pipeline variable
    model NVARCHAR(100),
    displacement DECIMAL(2, 1),
    cylinders TINYINT,
    transmission NVARCHAR(25),
    drive CHAR(3),
    fuel NVARCHAR(50),
    cert_region NVARCHAR(50),
    standard_code NVARCHAR(50),
    standard_code_desc NVARCHAR(50),
    underhood_ID nvarchar(50),
    EPA_vehicle_class NVARCHAR(50),
    air_pollution_score nvarchar(10), -- string to handle odd values like '10/15' or 'N/A*'
    city_MPG nvarchar(10),
    highway_MPG nvarchar(10),
    combined_MPG nvarchar(10),
    greenhouse_gas_rating nvarchar(10),
    smartway nvarchar(10),
    combined_CO2 SMALLINT
)