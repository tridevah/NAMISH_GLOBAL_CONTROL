import urllib.request
import hashlib

url = 'https://raw.githubusercontent.com/datasets/unece-units-of-measure/main/data/units-of-measure.csv'
print('Downloading...', url)
try:
    response = urllib.request.urlopen(url, timeout=20)
    data = response.read()
    with open('seed/unece_raw.csv', 'wb') as f:
        f.write(data)
    print('Saved to seed/unece_raw.csv')
    sha256 = hashlib.sha256(data).hexdigest()
    print('SHA-256:', sha256)
except Exception as e:
    print('Download failed:', e)
