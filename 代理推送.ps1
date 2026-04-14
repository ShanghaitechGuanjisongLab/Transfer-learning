$env:http_proxy = "http://127.0.0.1:8890"
$env:https_proxy = "http://127.0.0.1:8890"

git push

$env:http_proxy = $null
$env:https_proxy = $null
