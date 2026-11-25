# 실습용 Source Image 재빌드 (진행자용)

Zero-CVE 실습의 Source Image `quay.io/yeslee/rhel10-bootc:10.2`에
`workshop-rhel10` DNF 저장소를 **이미지 안에 내장**하는 빌드 파일입니다.

예전에는 저장소가 OpenShift 클러스터의 route(`…apps.cluster-xxxxx.dyn.redhatworkshops.io`)에 있어서,
클러스터가 만료되면 Step 2 빌드와 Step 4 kpatch가 `Could not resolve host`로 실패했습니다.
이제는 `baseurl=file:///usr/share/workshop-repo`를 사용하므로 repo 서버가 필요 없습니다.

## 들어가는 RPM

| 용도 | 패키지 |
|---|---|
| Step 2 Hardened Containerfile | rhc, insights-client, kpatch, kpatch-dnf (+ 베이스에 없는 의존성) |
| Step 4 kpatch | `kpatch-patch-6_12_0-211_16_1` |
| Step 5 Userspace Update | 설치된 `glibc*`, `openssl*`의 새 버전, `tree` |

- 원본 이미지의 설치 상태를 기준으로 계산하므로 이미 설치된 패키지는 다시 넣지 않습니다.
- `kernel*` RPM이 섞이면 빌드가 실패합니다. (커널 1개 lint, soft reboot 조건 보호)

## 빌드 방법

조건: **RHSM에 등록된 RHEL 10 호스트**, `sudo podman login quay.io`(yeslee 계정)

```bash
cd base-image
./build-base-image.sh            # 빌드 → 결과 확인 → push 여부 질문
PUSH=yes ./build-base-image.sh   # 바로 push
```

- 처음 실행하면 현재 `:10.2`를 `:10.2-remote-repo-backup`으로 백업합니다.
- 이후에는 항상 백업(원본)을 기준으로 빌드하므로 여러 번 실행해도 안전합니다.

## 빌드 후 확인할 것

- 출력의 `kpatch-patch:` 버전이 가이드의 `kpatch-patch-6_12_0-211_16_1-1-5.el10_2`와 같은지
  (다르면 가이드 Step 4의 기대값을 수정)
- `Step 5 업데이트 RPM` 목록에 설치 버전보다 새 버전이 있는지
  (없으면 Step 5는 `tree` marker로만 변경이 확인됨)
- 이미 예전 `:10.2`를 받아둔 호스트에서는 실습 전에 `sudo podman pull quay.io/yeslee/rhel10-bootc:10.2`
