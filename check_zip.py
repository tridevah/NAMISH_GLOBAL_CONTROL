import zipfile
import pandas as pd
import io
import warnings
warnings.filterwarnings('ignore')

zip_path = r'D:\ANTIGRAVITY_WORKSPACE\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\ANDAMAN AND NICOBAR ISLANDS\downloadDir2026_08_26_23_46_39_629.zip'

try:
    with zipfile.ZipFile(zip_path, 'r') as z:
        for filename in z.namelist():
            with z.open(filename) as f:
                raw = f.read(500).decode('utf-8', errors='ignore')
                f.seek(0)
                if '<html' in raw.lower() or '<table' in raw.lower():
                    try:
                        dfs = pd.read_html(f.read())
                        df = dfs[0]
                        print(f"File: {filename}, Rows: {len(df)}, Cols: {list(df.columns)[:5]}")
                    except Exception as e:
                        print(f"File: {filename}, HTML error: {e}")
                else:
                    try:
                        df = pd.read_excel(f)
                        print(f"File: {filename}, Rows: {len(df)}, Cols: {list(df.columns)[:5]}")
                    except Exception as e:
                        print(f"File: {filename}, Excel error: {e}")
except Exception as e:
    print('Zip error:', e)
