# QueryAndValidation UI
The QueryAndValidation UI is a web application that allows users to:
- Upload RDF Schema, SHACL shapes, and CIM XML files
- Query the uploaded data using SPARQL
- Validate the data against SHACL shapes

The Apache Jena framework and the OpenCGMES.CimXmlParser are used to provide robust functionality for handling CIM data.

The fist release is planned for end of 2025.

## Screenshots of the current state
Empty store without any uploaded files:
![Store](./images/screenshot_store_empty.png)

Filled store with uploaded files:
![Store](./images/screenshot_store_filled.png)

SPARQL query editor - querying RDF Schema for class properties:
![SPARQL Editor](./images/screenshot_sparql_class_properties.png)

SPARQL query editor - querying CIM XML data for aggregated wind power generation:
![SPARQL Editor](./images/screenshot_sparql_aggregated_wind_generation.png)

SHACL validation - example for a scuccessful validation:
![SHACL Validation](./images/screenshot_shacl_validaton_ok.png)

SHACL validation - example for a failed validation:
![SHACL Validation](./images/screenshot_shacl_validaton_error.png)