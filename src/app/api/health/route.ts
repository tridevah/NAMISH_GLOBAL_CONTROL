import { NextResponse } from 'next/server';
import * as fs from 'fs';
import * as path from 'path';

export async function GET() {
  let sha = process.env.RELEASE_SHA || null;
  if (!sha) {
    try {
      const shaPath = path.join(process.cwd(), '.release-sha');
      if (fs.existsSync(shaPath)) {
        sha = fs.readFileSync(shaPath, 'utf8').trim();
      }
    } catch {
      // ignore read errors
    }
  }
  return NextResponse.json(
    {
      status: 'ok',
      service: 'global-control',
      sha,
      releaseId: sha,
    },
    { status: 200 }
  );
}
