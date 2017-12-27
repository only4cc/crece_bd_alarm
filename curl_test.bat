curl -XGET "http://srv0013.e-contact.cl:9200/_search" -H 'Content-Type: application/json' -d'
{
    "query": {
        "query_string" : {
            "query" : "mssql",
            "use_dis_max" : true
        }
    }
}'

