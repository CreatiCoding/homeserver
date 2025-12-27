# T2 Mac mini Ubuntu 서버 열 관리 가이드

> Intel 기반 T2 Mac mini에서 Ubuntu 서버를 24/7 안정적으로 운영하기 위한 CPU, 팬, 쓰로틀링 설정 가이드

## 📋 목차

- [개요](#-개요)
- [시스템 요구사항](#-시스템-요구사항)
- [아키텍처](#-아키텍처)
- [빠른 시작](#-빠른-시작)
- [상세 설정](#-상세-설정)
- [모니터링 및 테스트](#-모니터링-및-테스트)
- [문제 해결](#-문제-해결)

## 🎯 개요

T2 Mac mini에서 Ubuntu를 홈서버로 운영할 때 직면하는 주요 과제들을 해결합니다:

- ✅ CPU 과열로 인한 성능 저하 방지
- ✅ 팬 소음 최소화 및 예측 가능한 제어
- ✅ 터보 부스트 폭주 억제
- ✅ 24/7 안정적인 운영 환경 구축

## 💻 시스템 요구사항

### 하드웨어

- Mac mini (2018 이상, T2 칩 탑재 모델)
- Intel Core i5/i7 프로세서

### 소프트웨어

- Ubuntu (t2-noble 커널 또는 T2 지원 커널)
- Root 권한

### 필수 패키지

```bash
sudo apt update
sudo apt install -y lm-sensors stress-ng
```

## 🏗 아키텍처

이 시스템은 세 가지 독립적인 레이어로 구성됩니다:

```
┌─────────────────────────────────────────────┐
│          Layer 3: 성능 상한 제어             │
│         (intel_pstate - 80% 제한)           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│          Layer 2: 열 기반 억제               │
│         (thermald - 70/80/90°C)             │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│          Layer 1: 물리적 냉각                │
│         (t2fanrd - 45~75°C 커브)            │
└─────────────────────────────────────────────┘
```

### 각 레이어의 역할

| 컴포넌트         | 역할                    | 제어 대상              |
| ---------------- | ----------------------- | ---------------------- |
| **intel_pstate** | CPU 최대 성능 상한 설정 | P-State (클럭 상한)    |
| **thermald**     | 열 기반 CPU 성능 억제   | CPU 주파수 (온도 기반) |
| **t2fanrd**      | 팬 속도 제어            | 팬 RPM (선형/2차 커브) |

## 🚀 빠른 시작

### 1단계: 필수 패키지 설치

```bash
# 센서 도구
sudo apt install -y lm-sensors
sudo sensors-detect --auto

# 팬 제어
sudo apt install -y t2fanrd
sudo systemctl enable --now t2fanrd

# 열 관리 데몬
sudo apt install -y thermald
sudo systemctl enable --now thermald
```

### 2단계: 기본 설정 적용

#### t2fanrd 설정

`/etc/t2fand.conf` 파일 생성:

```ini
[Fan1]
low_temp=45
high_temp=75
speed_curve=linear
always_full_speed=false
```

적용:

```bash
sudo systemctl restart t2fanrd
```

#### thermald 설정

`/etc/thermald/thermal-conf.xml` 파일 생성:

```xml
<?xml version="1.0"?>
<ThermalConfiguration>
  <Platform>
    <Name>T2 Mac mini Manual Policy</Name>
    <ProductName>Macmini</ProductName>
  </Platform>

  <ThermalZones>
    <ThermalZone>
      <Type>x86_pkg_temp</Type>

      <TripPoints>
        <TripPoint>
          <Temperature>70000</Temperature>
          <Type>passive</Type>
          <CoolingDevice>
            <Type>Processor</Type>
            <State>1</State>
          </CoolingDevice>
        </TripPoint>

        <TripPoint>
          <Temperature>80000</Temperature>
          <Type>passive</Type>
          <CoolingDevice>
            <Type>Processor</Type>
            <State>2</State>
          </CoolingDevice>
        </TripPoint>

        <TripPoint>
          <Temperature>90000</Temperature>
          <Type>passive</Type>
          <CoolingDevice>
            <Type>Processor</Type>
            <State>3</State>
          </CoolingDevice>
        </TripPoint>
      </TripPoints>
    </ThermalZone>
  </ThermalZones>
</ThermalConfiguration>
```

적용:

```bash
sudo systemctl restart thermald
```

#### intel_pstate 설정

tmpfiles.d를 사용한 영구 적용:

```bash
# 설정 파일 생성
echo 'w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 80' | sudo tee /etc/tmpfiles.d/intel-pstate.conf

# 즉시 적용
sudo systemd-tmpfiles --create /etc/tmpfiles.d/intel-pstate.conf

# 확인
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct
```

### 3단계: 동작 확인

```bash
# 서비스 상태 확인
systemctl is-active t2fanrd
systemctl is-active thermald

# CPU 성능 상한 확인
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

# 온도 및 팬 확인
sensors
```

## ⚙️ 상세 설정

### 1. intel_pstate - CPU 성능 상한

#### 설정값 가이드

- **100%**: 기본값 (터보 부스트 전체 활용)
- **80%**: 권장값 (발열↓, 체감 성능 유지)
- **60%**: 저전력 모드 (소음 최소화)

#### 즉시 변경 (재부팅 시 초기화됨)

```bash
echo 80 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct
```

#### 영구 적용

tmpfiles.d를 사용한 부팅 시 자동 적용:

```bash
echo 'w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 80' | sudo tee /etc/tmpfiles.d/intel-pstate.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/intel-pstate.conf
```

### 2. thermald - 열 기반 억제

#### 트립 포인트 정책

| 온도 | 동작    | 설명                       |
| ---- | ------- | -------------------------- |
| 70°C | State 1 | 완화된 억제 (터보 제한)    |
| 80°C | State 2 | 중간 억제 (기본 클럭 유지) |
| 90°C | State 3 | 강한 억제 (긴급 보호)      |

### 3. t2fanrd - 팬 제어

#### 설정 파일: `/etc/t2fand.conf`

```ini
[Fan1]
low_temp=45          # 팬 가속 시작 온도
high_temp=75         # 최대 RPM 도달 온도
speed_curve=linear   # linear 또는 quadratic
always_full_speed=false
```

#### 커브 선택 가이드

- **조용한 환경**: `linear` + `low_temp=50`
- **고부하 서버**: `quadratic` + `low_temp=45`

## 📊 모니터링 및 테스트

### 실시간 모니터링

```bash
watch -n 2 '
echo "=== CPU 상태 ===";
grep "cpu MHz" /proc/cpuinfo | awk "{sum+=\$4; count++} END {print \"평균 클럭: \" sum/count \" MHz\"}";
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct | awk "{print \"성능 상한: \" \$1 \"%\"}";
echo "";
echo "=== 온도 ===";
sensors | grep "Package id 0" | awk "{print \"CPU: \" \$4}";
echo "";
echo "=== 팬 ===";
sensors | grep -i fan | head -n1;
'
```

### 부하 테스트

헬스체크 스크립트 (`homeserver_healthcheck.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

DURATION="${DURATION:-10}"
THRESH_TOP80_AVG_C="${THRESH_TOP80_AVG_C:-95}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
SENSORS_SNAP_LOG="$TMPDIR/sensors_snapshots.log"
STRESS_LOG="$TMPDIR/stress.log"

echo "== HomeServer HealthCheck v9 =="
echo "• time: $(date)"
echo "• host: $(hostname)"
echo "• duration: ${DURATION}s"
echo "• rule: top80% core avg >= ${THRESH_TOP80_AVG_C}°C -> 비정상"
echo

# 필수 명령어 확인
for cmd in stress-ng sensors watch timeout; do
  command -v $cmd >/dev/null 2>&1 || { echo "비정상: $cmd 없음"; exit 2; }
done

echo "OK: prerequisites 확인 완료"
echo

export HS_SENSORS_LOG="$SENSORS_SNAP_LOG"

# 센서 로그 수집
echo "[1/2] sensors 스냅샷 로그 수집 시작"
timeout "${DURATION}s" watch -n 1 -t bash -lc '
  echo "----- $(date) -----" >> "$HS_SENSORS_LOG"
  sensors >> "$HS_SENSORS_LOG"
  echo >> "$HS_SENSORS_LOG"
' >/dev/null 2>&1 &
WATCH_PID=$!

# CPU 부하
echo "[2/2] CPU 부하 시작"
set +e
stress-ng --cpu 0 --cpu-method matrixprod --timeout "${DURATION}s" --metrics-brief >"$STRESS_LOG" 2>&1
STRESS_RC=$?
set -e

wait "$WATCH_PID" >/dev/null 2>&1 || true

echo
echo "OK: 부하 테스트 종료"
echo

# 온도 분석
RESULTS="$(
awk -v th="$THRESH_TOP80_AVG_C" '
  function reset_sample() {
    delete cores; n=0;
  }
  function sort_desc(arr, cnt,   i,j,tmp) {
    for (i=1; i<=cnt; i++)
      for (j=i+1; j<=cnt; j++)
        if (arr[j] > arr[i]) { tmp=arr[i]; arr[i]=arr[j]; arr[j]=tmp; }
  }
  function top80_avg(cnt,   k,i,sum) {
    if (cnt <= 0) return -1;
    k = int((cnt*8 + 9)/10);
    if (k < 1) k = 1;
    sum = 0;
    for (i=1; i<=k; i++) sum += cores[i];
    return sum / k;
  }
  BEGIN {
    max_top80=-1;
    reset_sample();
  }
  /^----- / {
    if (n > 0) {
      sort_desc(cores, n);
      v = top80_avg(n);
      if (v > max_top80) max_top80 = v;
    }
    reset_sample();
    next;
  }
  /^Core[[:space:]]+[0-9]+:/ {
    if (match($0, /([0-9]+(\.[0-9]+)?)°C/, m)) {
      t = m[1] + 0;
      n++;
      cores[n] = t;
    }
    next;
  }
  END {
    if (n > 0) {
      sort_desc(cores, n);
      v = top80_avg(n);
      if (v > max_top80) max_top80 = v;
    }
    printf("MAX_TOP80_AVG=%.1f\n", max_top80);
  }
' "$SENSORS_SNAP_LOG"
)"

eval "$RESULTS"

echo "• 관측 최고(top80% 코어 평균): ${MAX_TOP80_AVG}°C"
echo

FAIL_REASONS=()

if [[ "$STRESS_RC" -ne 0 ]]; then
  FAIL_REASONS+=("stress-ng 비정상 종료")
fi

if awk -v v="$MAX_TOP80_AVG" -v th="$THRESH_TOP80_AVG_C" 'BEGIN{ exit !(v>=th) }'; then
  FAIL_REASONS+=("상위 80% 코어 평균 ${MAX_TOP80_AVG}°C >= ${THRESH_TOP80_AVG_C}°C")
fi

if ((${#FAIL_REASONS[@]} == 0)); then
  echo "==== 판정: 정상 ===="
  exit 0
else
  echo "==== 판정: 비정상 ===="
  for r in "${FAIL_REASONS[@]}"; do
    echo " - $r"
  done
  exit 1
fi
```

**사용법:**

```bash
# 기본 실행 (10초)
chmod +x homeserver_healthcheck.sh
./homeserver_healthcheck.sh

# 30초 테스트
DURATION=30 ./homeserver_healthcheck.sh

# 임계값 90°C로 변경
THRESH_TOP80_AVG_C=90 ./homeserver_healthcheck.sh
```

### 예상 결과

| 항목      | 기본값 (100%) | 제한 (80%) |
| --------- | ------------- | ---------- |
| 최대 클럭 | 4.1 GHz       | 3.2 GHz    |
| 피크 온도 | 95°C          | 75°C       |
| 팬 소음   | 3500+ RPM     | 2500 RPM   |

## 🔧 문제 해결

### 팬이 전혀 돌지 않음

```bash
# 상태 확인
sudo systemctl status t2fanrd

# 재시작
sudo systemctl restart t2fanrd

# 팬 RPM 직접 확인
sensors | grep -i fan
```

### CPU 온도가 계속 높음 (80°C+)

```bash
# 1. 성능 상한 확인
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

# 2. 더 강한 제한 적용 (60%)
echo 60 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct

# 3. 팬 커브 조정
sudo nano /etc/t2fand.conf
# low_temp을 40으로 낮춤
sudo systemctl restart t2fanrd
```

### 성능이 너무 낮음

```bash
# 90%로 상향
echo 90 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct

# 영구 적용
echo 'w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 90' | sudo tee /etc/tmpfiles.d/intel-pstate.conf
```

### 설정 롤백

```bash
# intel_pstate 기본값 복원
echo 100 | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct
sudo rm /etc/tmpfiles.d/intel-pstate.conf

# thermald 기본 정책 복원
sudo rm /etc/thermald/thermal-conf.xml
sudo systemctl restart thermald

# t2fanrd 기본 설정
sudo mv /etc/t2fand.conf /etc/t2fand.conf.bak
sudo systemctl restart t2fanrd
```

## 📈 프로파일 전환

### 보수 모드 (조용함 최우선)

```bash
# CPU 60% 제한
echo 'w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 60' | sudo tee /etc/tmpfiles.d/intel-pstate.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/intel-pstate.conf

# 팬: low_temp=50, high_temp=75
```

### 균형 모드 (권장)

```bash
# CPU 80% 제한
echo 'w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 80' | sudo tee /etc/tmpfiles.d/intel-pstate.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/intel-pstate.conf

# 팬: low_temp=45, high_temp=75
```

### 성능 모드 (단기 작업)

```bash
# CPU 95% 제한
echo 'w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 95' | sudo tee /etc/tmpfiles.d/intel-pstate.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/intel-pstate.conf

# 팬: low_temp=40, high_temp=70
```

## 🐛 알려진 이슈

### T2 칩 관련

- **이슈**: 일부 커널에서 `apple_bce` 드라이버 충돌
- **해결**: T2 지원 커널(t2-noble) 사용 필수

### cpupower 미지원

- **이슈**: T2 커널에서 `cpupower` 패키지 없음
- **해결**: 본 가이드는 `sysfs` 기반으로 회피

## 📚 참고 자료

- [T2 Linux Wiki](https://wiki.t2linux.org/)
- [Intel P-State Documentation](https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_pstate.html)
- [thermald GitHub](https://github.com/intel/thermal_daemon)

## 📝 라이선스

MIT License

---

**⭐ 이 가이드가 도움이 되었다면 Star를 눌러주세요!**
