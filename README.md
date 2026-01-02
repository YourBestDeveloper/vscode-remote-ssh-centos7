# Enable VS Code Remote-SSH on CentOS 7

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CentOS 7](https://img.shields.io/badge/CentOS-7-blue.svg)](https://www.centos.org/)
[![VS Code](https://img.shields.io/badge/VS%20Code-Remote--SSH-blue.svg)](https://code.visualstudio.com/docs/remote/ssh)

> 🚀 Install glibc 2.28 and libstdc++ on CentOS 7 for VS Code Remote-SSH compatibility

[한국어](#한국어) | [English](#english)

---

## 한국어

### 📋 개요

CentOS 7은 2024년 6월 30일에 **EOL(End of Life)**을 맞이했으며, 기본 glibc 버전(2.17)이 너무 낮아 최신 VS Code Remote-SSH 서버가 작동하지 않습니다.

이 프로젝트는 CentOS 7에서 **glibc 2.28**과 **libstdc++.so.6 (GLIBCXX_3.4.21+)**을 설치하여 VS Code Remote-SSH를 사용할 수 있게 해주는 자동화 스크립트입니다.

### ⚠️ 해결하는 문제

#### 문제 1: CentOS 7 EOL로 인한 저장소 접근 불가
```bash
Could not resolve host: mirrorlist.centos.org
```

#### 문제 2: glibc 버전이 낮아 VS Code 서버 실행 불가
```bash
version `GLIBC_2.28' not found
```

#### 문제 3: libstdc++ 버전이 낮아 node 실행 불가
```bash
version `GLIBCXX_3.4.21' not found
version `CXXABI_1.3.9' not found
```

### ✨ 특징

- ✅ **완전 자동화**: 한 번의 실행으로 모든 설정 완료
- ✅ **멱등성 보장**: 재실행 가능 (이미 설치된 구성 요소는 건너뜀)
- ✅ **안전성**: 에러 처리 및 Fallback 로직 구현
- ✅ **EOL 대응**: vault.centos.org로 자동 전환
- ✅ **최신 라이브러리**: glibc 2.28 + libstdc++ (gcc 9.3.0)

### 🔧 설치 방법

#### 1단계: 스크립트 다운로드

```bash
# GitHub에서 다운로드
wget https://raw.githubusercontent.com/YourBestDeveloper/vscode-remote-ssh-centos7/main/enable-remote-ssh-centos7.sh

# 또는 curl 사용
curl -O https://raw.githubusercontent.com/YourBestDeveloper/vscode-remote-ssh-centos7/main/enable-remote-ssh-centos7.sh
```

#### 2단계: 실행

```bash
# 실행 권한 부여
chmod +x enable-remote-ssh-centos7.sh

# root로 실행
sudo bash enable-remote-ssh-centos7.sh
```

#### 3단계: VS Code Remote-SSH 연결

VS Code에서 Remote-SSH로 연결하면 자동으로 작동합니다! 🎉

### ⏱️ 소요 시간

프로세서 성능에 따라 **15-25분** 정도 소요됩니다.

### 🛠️ 기술적 세부사항

#### 설치되는 구성 요소

1. **glibc 2.28**
   - 설치 위치: `/opt/glibc-2.28`
   - VS Code 서버가 요구하는 최신 glibc

2. **libstdc++.so.6 (gcc 9.3.0)**
   - 설치 위치: `/opt/rh/devtoolset-9/root/usr/lib64`
   - GLIBCXX_3.4.21+, CXXABI_1.3.9+ 지원

3. **devtoolset-9**
   - gcc 9.3.1
   - make 4.2.1
   - g++ 9.3.1

#### 환경변수 설정

자동으로 다음 파일에 환경변수가 설정됩니다:

- `/etc/profile.d/vscode-glibc.sh`
- `/etc/environment`

```bash
export VSCODE_SERVER_CUSTOM_GLIBC_LINKER=/opt/glibc-2.28/lib/ld-2.28.so
export VSCODE_SERVER_CUSTOM_GLIBC_PATH=/opt/glibc-2.28/lib:/opt/rh/devtoolset-9/root/usr/lib64:/usr/lib64:/lib64
export VSCODE_SERVER_PATCHELF_PATH=/bin/patchelf
export LD_LIBRARY_PATH=/opt/rh/devtoolset-9/root/usr/lib64:${LD_LIBRARY_PATH}
```

### 📦 스크립트 구조

```
1. Root 권한 체크
2. CentOS 7 EOL 처리 (vault.centos.org 전환)
3. EPEL 저장소 활성화
4. 필수 패키지 설치
   4a. devtoolset-9 설치
   4b. libstdc++.so.6 빌드
5. glibc 2.28 빌드
6. 환경변수 설정
7. 완료
```

### 🔍 문제 해결

#### VS Code 연결이 여전히 실패하는 경우

```bash
# 환경변수 확인
cat /etc/profile.d/vscode-glibc.sh

# VS Code 서버 프로세스 종료 후 재시도
pkill -9 -f '.vscode-server'

# 스크립트 재실행
sudo bash enable-remote-ssh-centos7.sh
```

#### 특정 구성 요소만 재빌드

```bash
# libstdc++ 파일 삭제 후 재실행
sudo rm -f /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6*
sudo bash enable-remote-ssh-centos7.sh

# glibc 삭제 후 재실행
sudo rm -rf /opt/glibc-2.28
sudo bash enable-remote-ssh-centos7.sh
```

### ⚠️ 주의사항

- 이 스크립트는 **시스템 glibc를 교체하지 않습니다** (안전)
- `/opt/glibc-2.28`에 별도로 설치됩니다
- 기존 시스템 라이브러리는 영향받지 않습니다
- VS Code Remote-SSH 전용 설정입니다

### 🤝 기여

Issue 및 Pull Request를 환영합니다!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 📄 라이센스

MIT License - 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

### 🙏 감사

- [Visual Studio Code](https://code.visualstudio.com/) - Remote-SSH 기능
- [CentOS Project](https://www.centos.org/)
- [GNU libc](https://www.gnu.org/software/libc/)
- [GCC](https://gcc.gnu.org/)

---

## English

### 📋 Overview

CentOS 7 reached **EOL (End of Life)** on June 30, 2024, and its default glibc version (2.17) is too old for the latest VS Code Remote-SSH server.

This project provides an automated script to install **glibc 2.28** and **libstdc++.so.6 (GLIBCXX_3.4.21+)** on CentOS 7, enabling VS Code Remote-SSH functionality.

### ⚠️ Problems Solved

#### Problem 1: CentOS 7 EOL - Repository Access Denied
```bash
Could not resolve host: mirrorlist.centos.org
```

#### Problem 2: glibc Version Too Low
```bash
version `GLIBC_2.28' not found
```

#### Problem 3: libstdc++ Version Too Low
```bash
version `GLIBCXX_3.4.21' not found
version `CXXABI_1.3.9' not found
```

### ✨ Features

- ✅ **Fully Automated**: One-command setup
- ✅ **Idempotent**: Safe to re-run (skips already installed components)
- ✅ **Safe**: Comprehensive error handling and fallback logic
- ✅ **EOL Ready**: Automatically switches to vault.centos.org
- ✅ **Modern Libraries**: glibc 2.28 + libstdc++ (gcc 9.3.0)

### 🔧 Installation

#### Step 1: Download Script

```bash
# Download from GitHub
wget https://raw.githubusercontent.com/YourBestDeveloper/vscode-remote-ssh-centos7/main/enable-remote-ssh-centos7.sh

# Or use curl
curl -O https://raw.githubusercontent.com/YourBestDeveloper/vscode-remote-ssh-centos7/main/enable-remote-ssh-centos7.sh
```

#### Step 2: Run

```bash
# Make executable
chmod +x enable-remote-ssh-centos7.sh

# Run as root
sudo bash enable-remote-ssh-centos7.sh
```

#### Step 3: Connect with VS Code Remote-SSH

Connect via Remote-SSH in VS Code - it will work automatically! 🎉

### ⏱️ Execution Time

Approximately **15-25 minutes** depending on your processor performance.

### 🛠️ Technical Details

#### Installed Components

1. **glibc 2.28**
   - Location: `/opt/glibc-2.28`
   - Required by VS Code server

2. **libstdc++.so.6 (gcc 9.3.0)**
   - Location: `/opt/rh/devtoolset-9/root/usr/lib64`
   - Supports GLIBCXX_3.4.21+, CXXABI_1.3.9+

3. **devtoolset-9**
   - gcc 9.3.1
   - make 4.2.1
   - g++ 9.3.1

#### Environment Variables

Automatically configured in:

- `/etc/profile.d/vscode-glibc.sh`
- `/etc/environment`

```bash
export VSCODE_SERVER_CUSTOM_GLIBC_LINKER=/opt/glibc-2.28/lib/ld-2.28.so
export VSCODE_SERVER_CUSTOM_GLIBC_PATH=/opt/glibc-2.28/lib:/opt/rh/devtoolset-9/root/usr/lib64:/usr/lib64:/lib64
export VSCODE_SERVER_PATCHELF_PATH=/bin/patchelf
export LD_LIBRARY_PATH=/opt/rh/devtoolset-9/root/usr/lib64:${LD_LIBRARY_PATH}
```

### 🔍 Troubleshooting

#### VS Code Connection Still Fails

```bash
# Check environment variables
cat /etc/profile.d/vscode-glibc.sh

# Kill VS Code server and retry
pkill -9 -f '.vscode-server'

# Re-run script
sudo bash enable-remote-ssh-centos7.sh
```

#### Rebuild Specific Components

```bash
# Rebuild libstdc++
sudo rm -f /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6*
sudo bash enable-remote-ssh-centos7.sh

# Rebuild glibc
sudo rm -rf /opt/glibc-2.28
sudo bash enable-remote-ssh-centos7.sh
```

### ⚠️ Important Notes

- This script **does NOT replace system glibc** (safe)
- Installs separately in `/opt/glibc-2.28`
- Existing system libraries remain untouched
- Specific to VS Code Remote-SSH

### 🤝 Contributing

Issues and Pull Requests are welcome!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

### 🙏 Acknowledgments

- [Visual Studio Code](https://code.visualstudio.com/) - Remote-SSH feature
- [CentOS Project](https://www.centos.org/)
- [GNU libc](https://www.gnu.org/software/libc/)
- [GCC](https://gcc.gnu.org/)
