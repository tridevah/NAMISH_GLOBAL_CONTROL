import json
with open('D:/NAMISH_GLOBAL_CONTROL/r16_source/sealed_manifest_r16.json', 'r') as f:
    data = json.load(f)
    print(json.dumps(data['states'].get('DELHI', []), indent=2))
