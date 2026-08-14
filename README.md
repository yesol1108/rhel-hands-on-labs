# RHEL 10 Hands-on Workshop

RHEL 10 실습 환경과 가이드를 한 곳에서 열 수 있도록 구성한 Hands-on Workshop 저장소입니다.

## Workshop Hub

GitHub Pages의 메인 진입점은 **Hands-on Workshop Hub**입니다.

- Workshop Hub: `https://yesol1108.github.io/rhel-hands-on-labs/`
- Source: `docs/index.html`

Hub에서 실습 환경, 기본 실습, 추가 가이드를 바로 열 수 있습니다.

## Labs

### Lab 01 · Image Mode / Zero-CVE

**RHEL 10 최신 OS 패치 방안**

RHEL 10.0에서 RHEL 10.2 Image Mode로 전환하고 Hardened Image, kpatch, Userspace Update, systemd soft reboot 흐름을 실습합니다.

- Image Mode 기본 실습
- OpenTLC 실습 환경
- Zero-CVE 실습 가이드

### Lab 02 · Crypto Policy / PQC

**System-wide Crypto Policy + PQC**

기본 Crypto Policy 실습 후 Hybrid ML-KEM을 확인하고, 선택 단계로 ML-DSA 전자서명과 검증까지 진행합니다.

- System-wide Crypto Policy 기본 실습
- PQC 추가 실습 가이드

## Repository Structure

```text
rhel-hands-on-labs/
├── README.md
└── docs/
    ├── index.html              # Workshop Hub
    ├── guides/
    │   ├── zero-cve.html
    │   └── pqc-additional.html
    └── .nojekyll
```

## GitHub Pages

Pages 설정은 아래 값을 사용합니다.

- Source: `Deploy from a branch`
- Branch: `main`
- Folder: `/docs`

## Disclaimer

This repository is a personal technical lab project and is not official Red Hat product documentation.
For authoritative product information, refer to Red Hat's official product documentation.
