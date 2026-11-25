#!/bin/bash
# ------------------------------------------------------------
# Workshop 실습에 필요한 RPM만 모아 로컬 DNF 저장소를 만듭니다.
#
# - Containerfile의 collector stage 안에서 실행됩니다.
# - 원본 베이스 이미지의 설치 상태(rpmdb)를 기준으로 의존성을 계산하므로
#   이미 이미지에 설치된 패키지는 다시 받지 않습니다.
# - RPM은 빌드 호스트의 RHSM 구독(Red Hat CDN)에서 받습니다.
# - kernel RPM이 섞이면 실패합니다. (lint / soft reboot 조건 보호)
# ------------------------------------------------------------
set -euo pipefail

OUT="${OUT:-/workshop-repo}"
EXTRA_DIR="${EXTRA_DIR:-/tmp/extra-rpms}"

# Step 2 Hardened Containerfile에서 설치하는 패키지
HARDENED_PKGS=(openssh-server sudo podman rhc insights-client kpatch kpatch-dnf)

# Step 4 kpatch 실습 대상 (base image의 고정 kernel 6.12.0-211.16.1.el10_2 용)
KPATCH_PKG="kpatch-patch-6_12_0-211_16_1"
# 가이드 Step 4에 적힌 기대 버전
KPATCH_PIN="${KPATCH_PKG}-2-13.el10_2"

# Step 5 Userspace Update에서 설치하는 marker 패키지
USERSPACE_INSTALL_PKGS=(tree)

# 기존 원격 workshop 저장소는 사용하지 않고 Red Hat CDN만 사용
DNF_CACHE="/tmp/workshop-dnf-cache"
DNF=(dnf -y --disablerepo=workshop-rhel10 --setopt=install_weak_deps=False
     --setopt=keepcache=True --setopt=cachedir="${DNF_CACHE}")

# dnf 버전에 따라 --downloadonly 의 --destdir 가 무시되고 캐시에만 저장되는 경우가 있어
# 전용 캐시 디렉터리에 받은 뒤, 캐시의 RPM을 저장소 폴더로 모읍니다.
collect_from_cache() {
    find "${DNF_CACHE}" -name '*.rpm' -exec cp -n {} "${OUT}/" \; 2>/dev/null || true
}

mkdir -p "${OUT}"

echo "=== 1. Step 2/5 설치 패키지 + 의존성 (미설치분만) ==="
"${DNF[@]}" install --downloadonly --destdir "${OUT}" \
    "${HARDENED_PKGS[@]}" "${USERSPACE_INSTALL_PKGS[@]}"

echo "=== 2. Step 4 kpatch-patch ==="
# 1) base-image/extra-rpms/ 에 직접 넣어둔 RPM이 있으면 그대로 사용
if compgen -G "${EXTRA_DIR}/*.rpm" >/dev/null; then
    echo "extra-rpms 사용: $(cd "${EXTRA_DIR}" && ls -- *.rpm)"
    cp "${EXTRA_DIR}"/*.rpm "${OUT}/"
fi

if [ -z "$(find "${OUT}" -maxdepth 1 -name "${KPATCH_PKG}-*.rpm")" ]; then
    # 2) kpatch-patch-6_12_0-211_16_1 은 10.2 전용 저장소(EUS / 4 years of updates / ELS)로
    #    배포되므로, base image의 minor 버전(10.2)으로 해당 저장소를 켜고 찾습니다.
    #    가이드 기대값과 맞추기 위해 ${KPATCH_PIN} 을 먼저 시도하고, 없으면 최신 버전을 받습니다.
    BASE_RELEASEVER="$(. /etc/os-release && echo "${VERSION_ID}")"
    MINOR_REPOS=(--releasever="${BASE_RELEASEVER}"
                 --enablerepo='*baseos-eus-rpms' --enablerepo='*baseos-e4s-rpms'
                 --enablerepo='*baseos-els-rpms' --enablerepo='*baseos-aus-rpms')
    for ATTEMPT in \
        "기본 저장소 / ${KPATCH_PIN}|${KPATCH_PIN}|" \
        "10.2 전용 저장소 / ${KPATCH_PIN}|${KPATCH_PIN}|minor" \
        "10.2 전용 저장소 / 최신 버전|${KPATCH_PKG}|minor" \
        "기본 저장소 / 최신 버전|${KPATCH_PKG}|"; do
        IFS='|' read -r LABEL PKG MODE <<< "${ATTEMPT}"
        echo "--- kpatch-patch 시도: ${LABEL}"
        if [ "${MODE}" = "minor" ]; then
            "${DNF[@]}" "${MINOR_REPOS[@]}" --setopt=skip_if_unavailable=True \
                install --downloadonly --destdir "${OUT}" "${PKG}" && break || true
        else
            "${DNF[@]}" install --downloadonly --destdir "${OUT}" "${PKG}" && break || true
        fi
    done
fi

collect_from_cache
if [ -z "$(find "${OUT}" -maxdepth 1 -name "${KPATCH_PKG}-*.rpm")" ]; then
    echo "################################################" >&2
    echo "# ERROR: ${KPATCH_PKG} RPM을 찾지 못했습니다." >&2
    echo "#  아래 진단 정보 전체를 복사해서 전달해 주세요." >&2
    echo "#  RPM 파일을 가지고 있다면 base-image/extra-rpms/ 에 넣고 다시 빌드하세요." >&2
    echo "################################################" >&2
    echo "--- [진단] base image ---" >&2
    grep -E '^(NAME|VERSION_ID)=' /etc/os-release >&2
    rpm -q kernel-core >&2
    echo "--- [진단] 사용 가능한 저장소 ---" >&2
    dnf -q --disablerepo=workshop-rhel10 repolist -v 2>/dev/null | grep -E '^Repo-(id|baseurl)' >&2 || true
    echo "--- [진단] 구독에 포함된 10.2 전용 BaseOS 저장소 ---" >&2
    dnf -q repolist --all 2>/dev/null | grep -Ei 'baseos-(eus|e4s|els|aus)' >&2 || echo "(없음 - 이 구독에는 10.2 전용 저장소가 없습니다)" >&2
    echo "--- [진단] 저장소의 kpatch-patch (최근 15개) ---" >&2
    dnf -q --disablerepo=workshop-rhel10 repoquery 'kpatch-patch*' 2>/dev/null | sort | tail -15 >&2 || true
    echo "--- [진단] 저장소의 kernel-core 6.12.0-211* ---" >&2
    dnf -q --disablerepo=workshop-rhel10 repoquery --showduplicates 'kernel-core-6.12.0-211*' 2>/dev/null | sort | tail -10 >&2 || true
    exit 1
fi

echo "=== 3. Step 5 업데이트 대상 (설치된 glibc*/openssl* 의 새 버전) ==="
mapfile -t UPDATE_PKGS < <(rpm -qa --qf '%{name}\n' 'glibc*' 'openssl*' | sort -u)
echo "대상: ${UPDATE_PKGS[*]}"
if ! "${DNF[@]}" upgrade --downloadonly --destdir "${OUT}" "${UPDATE_PKGS[@]}"; then
    echo "WARN: glibc/openssl 새 버전이 없습니다. Step 5에서는 tree marker로만 변경이 확인됩니다."
fi

collect_from_cache

echo "=== 4. kernel RPM 혼입 검사 ==="
KERNEL_RPMS="$(find "${OUT}" -maxdepth 1 -name 'kernel*.rpm' -printf '%f\n')"
if [ -n "${KERNEL_RPMS}" ]; then
    echo "ERROR: 저장소에 kernel RPM이 포함되었습니다. 제거 대상:" >&2
    echo "${KERNEL_RPMS}" >&2
    exit 1
fi

echo "=== 5. kpatch-patch 포함 검사 ==="
if [ -z "$(find "${OUT}" -maxdepth 1 -name "${KPATCH_PKG}-*.rpm")" ]; then
    echo "ERROR: ${KPATCH_PKG} RPM을 받지 못했습니다." >&2
    exit 1
fi

echo "=== 6. 저장소 metadata 생성 ==="
# createrepo_c는 다운로드가 끝난 뒤 설치합니다.
# (먼저 설치하면 collector의 rpmdb가 바뀌어 의존성 계산 기준이 달라짐)
"${DNF[@]}" install createrepo_c
createrepo_c "${OUT}"

echo "=== 요약 ==="
echo "RPM 개수 : $(find "${OUT}" -maxdepth 1 -name '*.rpm' | wc -l)"
echo "저장소 크기: $(du -sh "${OUT}" | cut -f1)"
echo "kpatch-patch: $(find "${OUT}" -maxdepth 1 -name "${KPATCH_PKG}-*.rpm" -printf '%f\n')"
echo "--- Step 5 업데이트 RPM (설치 버전 → 저장소 버전) ---"
for p in "${UPDATE_PKGS[@]}"; do
    f="$(find "${OUT}" -maxdepth 1 -name "${p}-[0-9]*.rpm" -printf '%f\n' | head -1)"
    printf '%-28s %s → %s\n' "${p}" "$(rpm -q --qf '%{version}-%{release}' "${p}")" "${f:-없음}"
done
