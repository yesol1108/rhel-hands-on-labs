#!/bin/bash
# ------------------------------------------------------------
# 실습용 Source Image 재빌드 (workshop-rhel10 저장소 내장)
#
# 사용법 (RHSM 등록된 RHEL 10 호스트, Quay yeslee 계정 로그인 상태):
#   ./build-base-image.sh            # 빌드 후 push 여부를 물어봄
#   PUSH=yes ./build-base-image.sh   # 빌드 후 바로 push
#
# 처음 실행 시 현재 :10.2 이미지를 BACKUP_IMAGE 태그로 백업하고,
# 이후에는 항상 그 백업(원본)을 기준으로 빌드합니다. 여러 번 실행해도
# 레이어가 계속 쌓이지 않습니다.
# ------------------------------------------------------------
set -euo pipefail

TARGET_IMAGE="${TARGET_IMAGE:-quay.io/yeslee/rhel10-bootc:10.2}"
BACKUP_IMAGE="${BACKUP_IMAGE:-quay.io/yeslee/rhel10-bootc:10.2-remote-repo-backup}"
PUSH="${PUSH:-ask}"

cd "$(dirname "$0")"

echo "=== 0. 사전 확인 ==="
if ! sudo subscription-manager identity >/dev/null 2>&1; then
    echo "FAIL: 이 호스트가 RHSM에 등록되어 있지 않습니다. (Red Hat CDN에서 RPM을 받아야 함)" >&2
    exit 1
fi
if ! sudo podman login --get-login quay.io >/dev/null 2>&1; then
    echo "FAIL: quay.io에 로그인되어 있지 않습니다. sudo podman login quay.io" >&2
    exit 1
fi

echo "=== 1. 원본 이미지 백업 확인 ==="
if sudo podman pull "${BACKUP_IMAGE}" >/dev/null 2>&1; then
    echo "백업 이미지 사용: ${BACKUP_IMAGE}"
else
    echo "백업 이미지가 없어 현재 ${TARGET_IMAGE} 를 백업합니다."
    sudo podman pull "${TARGET_IMAGE}"
    sudo podman tag "${TARGET_IMAGE}" "${BACKUP_IMAGE}"
    sudo podman push "${BACKUP_IMAGE}"
fi

echo "=== 2. 빌드 ==="
sudo podman build \
    --build-arg BASE_IMAGE="${BACKUP_IMAGE}" \
    -t "${TARGET_IMAGE}" \
    -f Containerfile .

echo "=== 3. 결과 확인 ==="
sudo podman images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' \
    | grep -E "$(basename "${TARGET_IMAGE%%:*}")" || true
sudo podman run --rm "${TARGET_IMAGE}" sh -c '
    echo "--- 내장 저장소 ---"
    du -sh /usr/share/workshop-repo
    cat /etc/yum.repos.d/workshop-rhel10.repo
    echo "--- kernel ---"
    rpm -q kernel-core
'

echo "=== 4. Push ==="
if [ "${PUSH}" = "ask" ]; then
    read -r -p "${TARGET_IMAGE} 로 push 할까요? [y/N] " ANSWER
    [ "${ANSWER}" = "y" ] || [ "${ANSWER}" = "Y" ] && PUSH=yes || PUSH=no
fi
if [ "${PUSH}" = "yes" ]; then
    sudo podman push "${TARGET_IMAGE}"
    echo "OK: ${TARGET_IMAGE} push 완료"
else
    echo "push 하지 않았습니다. 나중에: sudo podman push ${TARGET_IMAGE}"
fi
