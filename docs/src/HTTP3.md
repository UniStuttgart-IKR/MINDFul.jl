# HTTP API

```@raw html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Swagger UI</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui.css">
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui-bundle.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui-standalone-preset.js"></script>
    <script>
        {"openapi":"3.0.0","paths":{"/api/compilation_algorithms":{"post":{"parameters":[],"requestBody":{"content":{"text/plain":{"schema":{"allOf":[],"type":"string"}},"application/xml":{"schema":{"type":"object"}},"multipart/form-data":{"schema":{"properties":{"file":{"format":"binary","type":"string"}},"required":["file"],"type":"object"}},"application/json":{"schema":{"allOf":[],"type":"object"}},"application/x-www-form-urlencoded":{"schema":{"allOf":[],"type":"object"}}},"required":false},"responses":{"500":{"description":"500 Server encountered a problem"},"200":{"description":"Successfully returned the compilation algorithms."}},"tags":["api endpoint"],"description":"Return the available compilation algorithms"}},"/api/spectrum_availability":{"post":{"parameters":[],"requestBody":{"content":{"text/plain":{"schema":{"allOf":[],"type":"string"}},"application/xml":{"schema":{"type":"object"}},"multipart/form-data":{"schema":{"properties":{"file":{"format":"binary","type":"string"}},"required":["file"],"type":"object"}},"application/json":{"schema":{"allOf":[],"properties":{"src":{"properties":{"ibnfid":{"type":"string"},"localnode":{"type":"integer"}},"type":"object"},"dst":{"properties":{"ibnfid":{"type":"string"},"localnode":{"type":"integer"}},"type":"object"}},"type":"object"}},"application/x-www-form-urlencoded":{"schema":{"allOf":[],"type":"object"}}},"required":true,"description":"The global edge for which to check spectrum availability"},"responses":{"500":{"description":"500 Server encountered a problem"},"200":{"description":"Successfully returned the spectrum availability."}},"tags":[],"description":"Return the spectrum availability"}}},"info":{"title":"MINDFul Api","version":"1.0.0"}}
    </script>
</body>
</html>
```