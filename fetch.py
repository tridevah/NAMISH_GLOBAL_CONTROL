import urllib.request
import json
try:
    url = 'https://api.github.com/repos/datasets/unece-units-of-measure/contents/data'
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=10) as response:
        print(response.read().decode())
except Exception as e:
    print('Failed:', e)
