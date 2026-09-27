import urllib.request
import json
url = 'https://api.github.com/repos/datasets/unece-units-of-measure/commits/main'
req = urllib.request.Request(url)
with urllib.request.urlopen(req, timeout=10) as response:
    print(json.loads(response.read().decode())['sha'])
