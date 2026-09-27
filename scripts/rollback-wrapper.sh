#!/bin/bash
export MOCK_IS_ROLLBACK=1
bash ./scripts/rollback-global-control.sh "$@"
