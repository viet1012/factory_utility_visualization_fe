# Factory Utility Visualization (FE)

Dashboard Flutter (chủ yếu chạy **Flutter Web**) giám sát tiện ích nhà máy: **điện, nước, khí nén, solar**.
Dữ liệu lấy từ backend Utility qua REST API (Dio), tự làm mới theo chu kỳ bằng `PollingCoordinator`.

---

## Mục lục

1. [Công nghệ](#1-công-nghệ)
2. [Chạy & build](#2-chạy--build)
3. [Cấu hình backend](#3-cấu-hình-backend)
4. [Cấu trúc thư mục](#4-cấu-trúc-thư-mục)
5. [Các màn hình (tab)](#5-các-màn-hình-tab)
6. [Polling (tự làm mới dữ liệu)](#6-polling-tự-làm-mới-dữ-liệu)
7. [API](#7-api)
8. [Xử lý lỗi & timeout](#8-xử-lý-lỗi--timeout)
9. [Test](#9-test)
10. [Lưu ý / vấn đề đã biết](#10-lưu-ý--vấn-đề-đã-biết)

---

## 1. Công nghệ

| Thành phần | Phiên bản / ghi chú |
|---|---|
| Dart SDK | `>=3.8.0 <4.0.0` |
| HTTP | `dio ^5.9.1` (backend Utility), `http 0.13.6` (chỉ dùng cho Weather) |
| State | `provider ^6.1.5+1` (ChangeNotifier) |
| Chart / Grid / Gauge | `syncfusion_flutter_charts`, `syncfusion_flutter_datagrid`, `syncfusion_flutter_gauges` (đều `30.1.42`) |
| Khác | `intl`, `shimmer`, `web` |
| Dev | `flutter_lints ^5.0.0`, `fake_async ^1.3.1` (test polling) |

Assets: `assets/images/` (ảnh nền MAP `SPC2_AM.png` ban ngày, `SPC2_AM_night.png` ban đêm (tạo từ ảnh ngày), `SPC2_*_trees.png` lớp tán cây che xe, …), font `Roboto`.

---

## 2. Chạy & build

### Chạy local

```bash
flutter pub get

# Dùng backend production mặc định
flutter run -d chrome

# Trỏ tới backend khác (vd. backend chạy local)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:9999
```

### Build web để deploy — `build_web.bat`

```bat
REM Build với backend production mặc định
build_web.bat

REM Build cho server khác
set API_BASE_URL=http://<host>:<port>
build_web.bat
```

Script thực hiện 8 bước:

1. `flutter pub get`
2. `flutter build web` (kèm `--dart-define=API_BASE_URL=...` nếu đặt biến môi trường)
3. Kiểm tra `build/web` có `index.html`, `main.dart.js`
4. **Xóa `flutter_service_worker.js`** (tránh cache bản cũ)
5. Thay `flutter_bootstrap.js` bằng bản custom ở [custom/flutter_bootstrap.js](custom/flutter_bootstrap.js)
6. **Cache-busting**: sửa `index.html` thành `flutter_bootstrap.js?v=<yyyyMMddHHmm>`; bootstrap custom đọc `?v=` và gắn vào `main.dart.js`
7. Xóa & tạo lại thư mục deploy `D:\Viet\Utility\BUILD_WEB\build\web` (chỉ thư mục `build\web`, giữ nguyên `Dockerfile`, `nginx.conf` ở thư mục gốc deploy)
8. `robocopy` build sang thư mục deploy, kiểm tra lại

> Đường dẫn deploy (`OUTPUT_ROOT`) đang hard-code trong `build_web.bat`; sửa biến này nếu build trên máy khác.

---

## 3. Cấu hình backend

Toàn bộ địa chỉ backend khai báo **duy nhất** tại [lib/utility_api/api_config.dart](lib/utility_api/api_config.dart):

```dart
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.122.16:9093', // production
);
```

`DioClient` ([lib/utility_api/dio_client.dart](lib/utility_api/dio_client.dart)) là singleton Dio dùng chung:

- Khởi tạo một lần trong `UtilityDashboardScreen._initializeNetwork()`; gọi `DioClient.dio` trước `init()` sẽ ném `StateError`.
- Timeout mặc định: connect 30s, receive 90s, send 30s (**trên Web không đặt sendTimeout** vì GET không có body).
- Header mặc định: `Accept: application/json`, `Content-Type: application/json`.
- Debug mode bật interceptor log `[DIO REQUEST]`, `[DIO BODY]`, `[DIO ERROR ...]`.
- Có sẵn `setHeader`, `removeHeader`, `setBearerToken(token)` (hiện backend **chưa dùng xác thực**), `clear()`.

---

## 4. Cấu trúc thư mục

```text
lib/
├── main.dart                         # MaterialApp → UtilityDashboardScreen
├── utility_api/
│   ├── api_config.dart               # API_BASE_URL
│   └── dio_client.dart               # Dio singleton
├── weather_widgets/                  # Hiệu ứng mưa trên MAP (OpenWeatherMap)
└── utility_dashboard/
    ├── utility_dashboard_screen.dart # Màn chính: side tab, khởi tạo API/Provider/Polling
    ├── utility_dashboard_overview/   # Tab MAIN (MAP): minute/hourly/daily/monthly, solar
    ├── utility_dashboard_fac_details/# Màn chi tiết từng Fac (overlay, period dashboard)
    ├── utility_all_factory_chart/    # Tab CHARTS (Minutes / Hourly / Daily)
    ├── monitoring/                   # Tab MONITORING (monitoring_screen.dart: thanh sub-tab)
    │   ├── electricity/              #   › ⚡ Electricity › Live (power usage)
    │   └── electric_consumption/     #   › ⚡ Electricity › Bill period (kỳ hóa đơn 21 → 20)
    │       ├── api/  controller/  model/
    │       └── widgets/              #     chart, ô chart + dialog phóng to, bảng Detail
    ├── water_check/                  #   › 💧 Water
    ├── utility_catalog/              # Tab SCADA TABLE (cây latest, lịch sử signal)
    ├── signal_health/                # Tab ALARMS (signal health matrix + history)
    ├── utility_dashboard_setting/    # Tab SETTING (SCADA / Channel / Para CRUD)
    ├── utility_dashboard_common/
    ├── utility_dashboard_widgets/
    └── shared/
        ├── charts/  download/  navigation/
        ├── formatters/               # month_formatter, period_basis_formatter (Calendar month / Bill period)
        ├── json/                     # json_read: jsonDouble / jsonInt / jsonText dùng chung cho fromJson
        ├── polling/                  # PollingCoordinator, scope, interval, task id
        ├── state/  visibility/
        ├── widgets/                  # … period_basis_note (dòng "Calendar month · …" + ⓘ)
custom/flutter_bootstrap.js           # Bootstrap custom (cache-busting)
assets/                               # images, fonts, docs (F2 electric consumption.xlsx)
test/                                 # Unit test
build_web.bat                         # Script build & deploy web
```

Mỗi module theo cùng bố cục: `api/` (gọi HTTP) → `models/` (fromJson) → `controllers/` hoặc `providers/` (ChangeNotifier) → `widgets/` / `screens/`.

---

## 5. Các màn hình (tab)

Thanh tab dọc (`IndustrialSideTabBar`), nội dung dùng `IndexedStack` (giữ state khi đổi tab).

| # | Tab | Thư mục | Nội dung chính | API dùng |
|---|---|---|---|---|
| 0 | **MAIN** (MAP) | `utility_dashboard_overview/` | Bản đồ nhà máy, biểu đồ minute/hourly/daily, panel SUMMARY tháng, ô Fac_A/B/C, Solar, alarm map, thời tiết | minute-dashboard, hourly-dashboard, energy-daily, monthly-summary, solar/*, signal-health-matrix |
| — | Facility detail (route con) | `utility_dashboard_fac_details/` | Layout box theo Fac, overlay kéo-thả, period dashboard WEEK/MONTH | latest?facId, overlay, overlay/upsert, period-dashboard |
| — | Solar detail (route con) | `utility_dashboard_overview_solar/` | Trend ngày, cost/CO₂ impact, kWh theo giờ | solar/detail, solar/hourly |
| 1 | **CHARTS** | `utility_all_factory_chart/` | Biểu đồ signal Minutes / Hourly / Daily theo Fac + Cate | chart-catalog, series/history |
| 2 | **MONITORING** | `monitoring/`, `water_check/` | Sub-tab: ⚡ Electricity › **Live** · **Bill period** │ 💧 **Water** (có fullscreen) — xem [5.1](#51-bill-period) | power-usage, electric-consumption, water-check |
| 3 | **SCADA TABLE** | `utility_catalog/` | Cây Fac → Cate → SCADA → Box → Device → Signal, sparkline/filter chart | latest, series/history |
| 4 | **ALARMS** | `signal_health/` | Ma trận signal health, lịch sử cảnh báo theo giờ, export Excel | signal-health-matrix, signal-health/history/hourly, export |
| 5 | **SETTING** | `utility_dashboard_setting/` | CRUD SCADA, Channel, Para (ngưỡng cảnh báo) | /api/v1/utility-scada, -channels, -para |

Liên kết chéo giữa tab:

- **Water check › Open in Charts** → CHARTS › Minutes, focus đúng Fac / box / PLC (`cate = Water`).
- **Electricity › Compressed air › meter** → CHARTS › Hourly của box (`cate = Electricity`).

### 5.1 Bill period

MONITORING › ⚡ Electricity › **Bill period**.

Bản web của sheet **"FY26-Sep + Solar1"** trong [assets/docs/F2 electric consumption.xlsx](assets/docs/F2%20electric%20consumption.xlsx) (ELECTRIC CONSUMPTION DAILY MONITORING). Màn: [electric_consumption_screen.dart](lib/utility_dashboard/monitoring/electric_consumption/electric_consumption_screen.dart).

- **Header:** kỳ hóa đơn (`‹ Nov 2026 ›`, nút *Current*), số kỳ lịch sử `6M / 12M / 24M`, chế độ xem **Overview | Charts**, bật/tắt bảng **Detail**. Subtitle có ⓘ giải thích kỳ hóa đơn khác tháng dương lịch.
- **Overview** — mỗi scope (`TTL KVH: A&B + C`, `Fac A&B`, `Fac C`) một card:
  - KPI: *Period to date* (MWh, K$), *Avg / day* và *Cost / day* (so với trung bình kỳ trước), *High-peak share*, *Solar share* (chỉ KVH).
  - 2 chart **Consumption [MWh]** và **Amount [K$]**: cột chồng Normal / High-peak / Low-peak (+ Solar với KVH), đường Total; trục X = các kỳ trước (*Avg / day*) + từng ngày của kỳ. Nút ⤢ mở chart lớn (đổi scope / đơn vị ngay trong hộp thoại).
  - Bảng **Detail** như dòng 28–45 của sheet: cột *Description* ghim trái, cột *Total* / *Avg / day* ghim phải, phần giữa cuộn ngang (kéo chuột, Shift + con lăn, nút ◀ ▶). Mở bảng tự cuộn tới **ngày hiện tại** (cột *Today* tô cyan, nút *Today* để quay lại). Nút copy → dán thẳng vào Excel (giữ đủ 3 số lẻ).
- **Charts** — lưới 6 chart (3 scope × MWh | K$) vừa khít màn hình.
- **Dữ liệu chưa đủ:** ngày có `partial = true` (coverage < `minCoveragePct`) vẽ cột mờ + `*`, **không tính vào Avg / day**; chi tiết (coverage %, số meter, thay đổi số meter so với ngày trước, MWh bị loại) xem bằng **hover** tooltip. Kỳ trước không có dữ liệu (`null`, hoặc toàn `0.000` với backend cũ) bị ẩn khỏi chart / bảng.
- **Excluded meters:** dòng ghi chú chỉ hiện số lượng (`1 meter excluded`); hover để xem mã meter và lượng MWh bị loại theo từng kỳ.
- **Làm tròn hiển thị** (`ConsumptionFormat`): MWh 1 số lẻ (tổng kỳ: số nguyên), K$ 2 số lẻ (tổng kỳ: 1 số lẻ), đơn giá $/kWh 4 số lẻ.
- **Màu chart:** 4 màu categorical đã kiểm tra contrast / mù màu trên nền card `#0A1A2C` (`ConsumptionColors` trong [consumption_chart.dart](lib/utility_dashboard/monitoring/electric_consumption/widgets/consumption_chart.dart)).

#### Kỳ tính: tháng dương lịch vs kỳ hóa đơn

| Nơi hiển thị | API | Kỳ tính |
|---|---|---|
| Panel **SUMMARY** (MAIN), **Solar** detail | `monthly-summary`, `solar/monthly`, `solar/detail` | **Tháng dương lịch** (ngày 1 → cuối tháng; tháng hiện tại = đến hôm nay) |
| MONITORING › **Bill period** | `electric-consumption` | **Kỳ hóa đơn** (21 tháng trước → 20 tháng này) |

Cùng "tháng 11" nhưng số kWh / USD hai nơi khác nhau là **đúng thiết kế**. UI ghi rõ kỳ tính: SUMMARY và Solar detail có dòng `Calendar month · Nov 1 – Nov 12 ⓘ`, Bill period có ⓘ ở subtitle (helper [period_basis_formatter.dart](lib/utility_dashboard/shared/formatters/period_basis_formatter.dart), "hôm nay" tính theo giờ nhà máy **UTC+7**).

---

## 6. Polling (tự làm mới dữ liệu)

Thư mục [lib/utility_dashboard/shared/polling/](lib/utility_dashboard/shared/polling/).

- `PollingCoordinator`: đăng ký task (`id`, `scope`, `interval`, `action`), chỉ chạy khi **scope đang active**.
- `PollingScope` có quan hệ cha–con (vd. `mapMinutely` cần `map` active).
- Tab trình duyệt bị ẩn → **pause toàn bộ**. Dashboard bị route chi tiết che → **suppress** các scope của dashboard; scope `facilityDetail` / `solarDetail` vẫn chạy.
- Hiện lại → chạy ngay một lượt cho scope đang hiện; task chu kỳ ≥ 1h chỉ chạy khi đã quá hạn (`catchUpOnly`).

Chu kỳ ([dashboard_polling_intervals.dart](lib/utility_dashboard/shared/polling/dashboard_polling_intervals.dart)):

| Task | Scope | Chu kỳ | API |
|---|---|---|---|
| scadaLatestTree | scadaTable | 1 phút | `GET /api/utility/latest` |
| facilityLatest | facilityDetail | 1 phút | `GET /api/utility/latest?facId=` |
| mapMinuteDashboard | mapMinutely | 50 giây | `GET /api/utility/minute-dashboard` |
| mapHourlyDashboard | mapHourly | 30 phút | `GET /api/utility/hourly-dashboard` |
| mapDailyDashboard | map | 1 giờ | `GET /api/utility/energy-daily` |
| mapMonthlySummary | map | 1 giờ | `GET /api/utility/monthly-summary` |
| signalHealthMap | map | 5 phút | `GET /api/utility/signal-health-matrix` |
| signalHealthAlarms | alarms | 1 phút | `GET /api/utility/signal-health-matrix` |
| chartsMinuteSeries | chartsMinutes | 1 phút | `GET /api/utility/series/history` |
| chartsHourlySeries | chartsHourly | 5 phút | `GET /api/utility/series/history` |
| mapSolarMonthly | map | 10 phút | `GET /api/solar/monthly` |
| solarDetail | solarDetail | 1 giờ | `GET /api/solar/detail` |
| mapWeather | map | 45 phút | OpenWeatherMap |
| waterCheck | waterCheck | 15 giây | `GET /api/utility/water-check` |
| electricityPowerUsage | electricity | 1 phút (chỉ khi xem hôm nay) | `GET /api/utility/power-usage` |
| electricConsumption | electricConsumption | 10 phút (chỉ khi xem kỳ hiện tại) | `GET /api/utility/electric-consumption` |
| filterHistoryCheck | scadaTable | 30 giây (kiểm tra cache hết hạn) | `GET /api/utility/series/history` |

---

## 7. API

Base URL: `apiBaseUrl` (mục 3). Tất cả request/response là JSON trừ `/api/utility/export` (file `.xlsx`).
Không có xác thực. Giá trị Fac thường gặp: `KVH` (toàn nhà máy), `Fac_A`, `Fac_B`, `Fac_C`.

### Tổng hợp endpoint

| Method | Endpoint | Client (Dart) | Mục đích |
|---|---|---|---|
| GET | `/api/utility/latest` | `UtilityLatestApi.getLatestTree` | Cây giá trị mới nhất |
| GET | `/api/utility/minute-dashboard` | `UtilityDashboardOverviewApi.getMinuteDashboard` | MAP – theo phút |
| GET | `/api/utility/hourly-dashboard` | `UtilityDashboardOverviewApi.getHourlyDashboard` | MAP – theo giờ |
| GET | `/api/utility/energy-daily` | `UtilityDashboardOverviewApi.getDailyDashboard` | MAP – theo ngày |
| GET | `/api/utility/monthly-summary` | `UtilityDashboardOverviewApi.getMonthlySummary` | Tổng hợp tháng |
| POST | `/api/utility/monthly-summary/refresh` | `UtilityDashboardOverviewApi.forceRefreshMonthlySummary` | Tính lại tổng hợp tháng |
| GET | `/api/utility/period-dashboard` | `UtilityPeriodApi.getDashboard` | Fac detail – tuần/tháng |
| GET | `/api/utility/overlay` | `UtilityFacadeService.getOverlayGroups` | Vị trí overlay box |
| POST | `/api/utility/overlay/upsert` | `UtilityFacadeService.setOverlayGroupPos` | Lưu vị trí overlay |
| GET | `/api/utility/chart-catalog` | `UtilityChartApi.getChartCatalog` | Danh sách signal vẽ chart |
| GET | `/api/utility/series/history` | `UtilityChartApi.getSeriesHistory` | Lịch sử signal theo bucket |
| GET | `/api/utility/water-check` | `WaterCheckApi.fetch` | Kiểm tra mực/áp nước |
| GET | `/api/utility/power-usage` | `PowerUsageApi.fetch` | Điện tiêu thụ ngày/tuần/tháng |
| GET | `/api/utility/electric-consumption` | `ElectricConsumptionApi.fetch` | Điện theo kỳ hóa đơn |
| GET | `/api/utility/signal-health-matrix` | `SignalHealthApi.getSignalHealthMatrix` | Ma trận tình trạng signal |
| GET | `/api/utility/signal-health/history/hourly` | `SignalHealthHistoryApi.getHourlyHistory` | Lịch sử cảnh báo theo giờ |
| GET | `/api/utility/export` | `SignalHealthApi.getSignalHealthExport` | Xuất Excel signal health |
| GET | `/api/solar/monthly` | `SolarApi.getMonthly` | Solar – tóm tắt tháng |
| GET | `/api/solar/detail` | `SolarApi.getDetail` | Solar – chi tiết tháng |
| GET | `/api/solar/hourly` | `SolarApi.getHourly` | Solar – kWh theo giờ |
| GET | `/api/v1/utility-scada` | `UtilityScadaApi.getAll` | Danh sách SCADA |
| POST | `/api/v1/utility-scada` | `UtilityScadaApi.create` | Tạo SCADA |
| PUT | `/api/v1/utility-scada/{id}` | `UtilityScadaApi.update` | Sửa SCADA |
| GET | `/api/v1/utility-scada-channels` | `UtilityScadaChannelApi.getAll` | Danh sách channel |
| GET | `/api/v1/utility-scada-channels/group-by-fac` | `UtilityScadaChannelApi.getGroupedByFac` | Cây channel theo Fac |
| POST | `/api/v1/utility-scada-channels` | `UtilityScadaChannelApi.create` | Tạo channel |
| PUT | `/api/v1/utility-scada-channels/{id}` | `UtilityScadaChannelApi.update` | Sửa channel |
| GET | `/api/v1/utility-para/grouped-by-fac-with-paras` | `UtilityParaApi.getGroupedByFacWithParas` | Cây para theo Fac |
| POST | `/api/v1/utility-para` | `UtilityParaApi.create` | Tạo para |
| PUT | `/api/v1/utility-para/{id}` | `UtilityParaApi.update` | Sửa para |

> Field response bên dưới liệt kê theo những gì model FE **đang parse** (`fromJson`), không phải toàn bộ schema backend.

---

### 7.1 Latest — SCADA TABLE / Facility detail

#### `GET /api/utility/latest`

File: [utility_latest_api.dart](lib/utility_dashboard/utility_catalog/api/utility_latest_api.dart) · Model: [latest_tree_response.dart](lib/utility_dashboard/utility_catalog/models/latest_tree_response.dart)

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | Không | Lọc theo Fac; bỏ trống = tất cả (không gửi nếu rỗng) |

Response: **mảng** cây lồng nhau

```text
[ { fac, categories: [
      { cate, scadas: [
          { scadaId, boxes: [
              { boxId, devices: [
                  { boxDeviceId, signals: [
                      { plcAddress, cateId, nameEn, value, unit, recordedAt, kind }
]}]}]}]}]
```

---

### 7.2 Overview (tab MAIN)

File: [utility_dashboard_overview_api.dart](lib/utility_dashboard/utility_dashboard_overview/api/utility_dashboard_overview_api.dart)

#### `GET /api/utility/minute-dashboard`

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | FE: có · BE: không (mặc định `KVH`) | FE không cho rỗng |
| `minutes` | Không | Mặc định `60`, kẹp trong `1..1440` (≤ 0 → 60) |

Response (object): `electricity`, `water`, `air` — mỗi nhóm là danh sách điểm `{ ts, value, nameEn, name }`.

#### `GET /api/utility/hourly-dashboard`

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | FE: có · BE: không (mặc định `KVH`) | |

Luôn trả 24 giờ **hôm nay vs hôm qua** (không có tham số khoảng thời gian).

Response (object): `electricity` (điện lưới, không gồm solar — điểm `{ scaleHour, today, yesterday, todayUsd, yesterdayUsd }`), `water`, `air` (điểm sensor theo giờ). Solar theo giờ dùng `GET /api/solar/hourly`.

#### `GET /api/utility/energy-daily`

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | Có | |
| `month` | Có | `yyyyMM`, vd. `202611` (FE validate định dạng và tháng 1–12) |

Response (object):
- `electricity`: `[{ date | recordDate, gridKwh, solarKwh, totalKwh }]`
- `water`, `air`: `[{ date | recordDate, value }]`

#### `GET /api/utility/monthly-summary` · `POST /api/utility/monthly-summary/refresh`

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | Không | Rỗng → FE gửi `KVH` |
| `month` | Có | `yyyyMM` |

- `POST .../refresh`: tham số **trên query** (không có body), buộc backend tính lại.
- Response: **mảng** `EnergyMonthlySummary`:
  `cate, name, month, unit, value, minValue, maxValue, avgValue, vndCost, usdCost, prevValue, prevAvgValue, prevVndCost, prevUsdCost, deltaPercent, generatedAt | pickAt | timestamp`
- FE chuẩn hóa: `Total Energy Consumption` → `Total Energy`, `Total Water Consumption` → `Total Water`; `month` rỗng → lấy tháng request.
- Kết quả được cache/dedupe trong `MonthlySummaryStore`, dùng chung giữa panel SUMMARY và ô Fac_A/B/C.

---

### 7.3 Facility detail

#### `GET /api/utility/period-dashboard`

File: [utility_period_api.dart](lib/utility_dashboard/utility_dashboard_fac_details/api/utility_period_api.dart) · Model: [utility_period_dashboard.dart](lib/utility_dashboard/utility_dashboard_fac_details/models/period/utility_period_dashboard.dart)

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | FE: có · BE: không (mặc định `KVH`) | |
| `type` | FE: có · BE: không (mặc định `ELECTRICITY`) | `ELECTRICITY` \| `WATER` \| `AIR` |
| `period` | FE: có · BE: không (mặc định `WEEK`) | `WEEK` \| `MONTH` |
| `date` | FE: có · BE: không (mặc định hôm nay) | `yyyyMMdd` (ngày tham chiếu) |

Response (object): `fromDate, toDate, unit, total, changePercent, trend[{date, value}], byBox[...], columns, boxTrend[{boxId, values}], columnTotals, grandTotal`.

#### `GET /api/utility/overlay`

File: [utility_facade_service.dart](lib/utility_dashboard/utility_dashboard_fac_details/api/utility_facade_service.dart)

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | Có | Rỗng → FE không gọi API |

Response: **mảng** `{ boxDeviceId, x, y, direction, color }`
- `x`, `y`: tọa độ chuẩn hóa `0..1` (thiếu → `0.2`, FE kẹp vào `0..1`)
- `direction`: hướng mũi tên (mặc định `right`)

#### `POST /api/utility/overlay/upsert`

Body:

```json
{
  "facId": "Fac_A",
  "boxDeviceId": "BOX-01",
  "x": 0.35,
  "y": 0.62,
  "direction": "right",
  "color": "#00CFFF"
}
```

- `direction`: tên enum `ArrowDirection`.
- `color` **chỉ gửi khi có giá trị** — gửi `null` có thể làm backend xóa màu cũ.
- `facId` / `boxDeviceId` rỗng → FE bỏ qua, không gọi API.

---

### 7.4 CHARTS

File: [utility_chart_api.dart](lib/utility_dashboard/utility_all_factory_chart/api/utility_chart_api.dart)

#### `GET /api/utility/chart-catalog`

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `facId` | FE: có · BE: không (bỏ trống = mọi Fac) | |
| `cate` | FE: có · BE: không (bỏ trống = mọi cate) | vd. `Electricity`, `Water` |
| `importantOnly` | Không | `0` (mặc định) / `1` — chỉ lấy signal quan trọng |

Response: `{ items: [{ scadaId, boxId, boxDeviceId, plcAddress, kind, unit, cateId, nameEn }] }`

#### `GET /api/utility/series/history`

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `boxDeviceId` | Có | Một hoặc nhiều box, **CSV** (`BOX1,BOX2`); FE trim + bỏ trùng |
| `plcAddress` | Không | CSV; áp cho mọi box; bỏ trống = mọi PLC |
| `from` | Có | ISO-8601 **có offset**, vd. `2026-10-12T08:00:00+07:00` (`+` được encode `%2B`) |
| `to` | Có | Như `from` |
| `bucket` | Không | Mặc định `auto` (backend tự chọn bucket) |

Response (object):

```text
{ bucket, source, aggregation,
  signals: [ { boxDeviceId, plcAddress, name, code, unit, kind,
               alertLevel, thresholdLow, thresholdHigh, thresholds,
               breachCount, lastBreachAt,
               points: [ { ts, count, min, avg, max, last, delta } ] } ] }
```

Dùng chung qua `SignalHistoryRepository` (cache + dedupe) cho CHARTS (Minutes/Hourly/Daily) và SCADA TABLE. Request bị hủy (`CancelToken`) khi đổi range/timeout không bị coi là lỗi.

---

### 7.5 MONITORING

#### `GET /api/utility/power-usage` — Electricity

File: [power_usage_api.dart](lib/utility_dashboard/monitoring/electricity/api/power_usage_api.dart) · Model: [power_usage.dart](lib/utility_dashboard/monitoring/electricity/model/power_usage.dart) · receiveTimeout 30s

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `date` | Có | `yyyy-MM-dd` |
| `period` | Có | `day` \| `week` \| `month` |

Response (object), các field chính:
- `period, from, to, prevFrom, prevTo`
- `total`: `{ kwh, prevKwh, changePct, usd, blendedRate }`
- `forecast`: `{ monthToDateKwh, projectedKwh, dayOfMonth, daysInMonth, changePctVsPrevMonth }`
- `byFactory`: `[{ facId, kwh, sharePct, ... }]`
- `byPurpose`: theo mục đích (`code, name, description`, danh sách `meters` `{ boxDeviceId, label, kwh, last7 }`), `purposeConfigured`
- `supplyMix`: `[{ band, rate, kwh, usd, ... }]`
- `last7`, `last7Total`: `[{ date, kwh }]`

#### `GET /api/utility/electric-consumption` — Elec. consumption

File: [electric_consumption_api.dart](lib/utility_dashboard/monitoring/electric_consumption/api/electric_consumption_api.dart) · Model: [electric_consumption.dart](lib/utility_dashboard/monitoring/electric_consumption/model/electric_consumption.dart) · receiveTimeout 60s

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `month` | Không | Kỳ hóa đơn `yyyy-MM`; bỏ trống = kỳ hiện tại |
| `months` | Không | Số kỳ trước đưa vào `monthly`, `0..36` (mặc định `12`) |

Response (object), các field FE đang parse:

- `month`, `billPeriod`: `{ month, label, from, to, days }` (`to` là mốc kết thúc, exclusive)
- `dataUntil`: ISO kèm `+07:00`; khác `00:00` → ngày đó đang chạy dở
- `tariffAvailable`; `unitPrices`: `{ gridNormal, gridHighPeak, gridLowPeak, solarNormal, solarHighPeak, solarLowPeak }` ($/kWh, `null` khi không có biểu giá)
- `minCoveragePct`, `historyStartDate`, `excludedMeters[]` (optional)
- `scopes`: `[{ code (KVH | FAC_AB | FAC_C), name, monthly, daily, dailyTotalMwh, dailyTotalKusd, dailyAverageMwh, dailyAverageKusd, elapsedDays, meters, daysWithData, completeDays }]`
  - `monthly[]`: `{ month, label, days, perDayMwh, perDayKusd, partial, meters, daysWithData, completeDays, excludedMwh }` — trung bình / ngày của các kỳ trước
  - `daily[]`: `{ date, weekday, mwh, kusd, partial, coveragePct, hoursWithData, meters, excludedMwh }` — đủ số ngày của kỳ, ngày chưa tới `mwh`/`kusd` = `null`
  - Bộ giá trị (`perDayMwh`, `mwh`, …): `{ normal, highPeak, lowPeak, solar, totalElectricity (điện lưới), total (lưới + solar) }`
- `dailyAverage*` (backend mới): chỉ tính trên các ngày đủ dữ liệu. Các field optional thiếu (backend cũ) → FE tự suy ra (ngày dở từ `dataUntil`, trung bình trên ngày đủ).

Lỗi `400` (sai `month`, `months` ngoài `0..36`, kỳ chưa bắt đầu): hiển thị `message` trong body.

#### `GET /api/utility/water-check` — Water check

File: [water_check_api.dart](lib/utility_dashboard/water_check/api/water_check_api.dart) · Model: [water_check_models.dart](lib/utility_dashboard/water_check/models/water_check_models.dart) · receiveTimeout 30s · không có tham số

Response (object):
- `generatedAt`, `config`
- `summary`: số lượng theo trạng thái `ok, near, over, stale, noThreshold, stopped, sensorFault, trivial`
- `facilities`: `[{ facId, groups: [{ code, name, unit, thresholdText, thresholds, signals: [...] }] }]`
  - signal: `boxDeviceId, deviceName, plcAddress, name, label, value, rawValue, median, medianValue, recordedAt, status, distance, trend1h, since, lastValue, lastSeenAt, thresholds { level, low, high }`
- `issues`: danh sách signal bất thường

---

### 7.6 ALARMS (Signal health)

#### `GET /api/utility/signal-health-matrix`

File: [signal_health_api.dart](lib/utility_dashboard/signal_health/api/signal_health_api.dart) · không có tham số

Response: **mảng** object (FE giữ dạng `Map`). Field được UI đọc: `fac, cate, cateId, scadaId, boxDeviceId, plcAddress, name, nameEn, unit, status, level, rule, errorType, currentValue, prevValue, jumpSize, recordedAt, totalRegisters, ngRegisters, ...`

#### `GET /api/utility/signal-health/history/hourly`

File: [signal_health_history_api.dart](lib/utility_dashboard/signal_health/api/signal_health_history_api.dart) · Model: [signal_health_history_models.dart](lib/utility_dashboard/signal_health/models/signal_health_history_models.dart)

| Query | Bắt buộc | Mô tả |
|---|---|---|
| `from` | Có | `yyyy-MM-ddTHH:mm:ss` giờ local, **không** `Z`/offset |
| `to` | Có | Như `from` |
| `fac` | Không | Bỏ qua nếu rỗng hoặc `ALL` |
| `cate` | Không | Như trên |
| `scadaId` | Không | Như trên |
| `boxDeviceId` | Không | Như trên |

Response: mảng bucket, hoặc object bọc mảng trong `data` / `buckets` / `items` / `result`.

```text
[ { bucketTime, errorCount,
    alerts: [ { level, descriptions: [ { ruleType, parameterCode, description,
        devices: [ { boxDeviceId, signals: [
            { plcAddress, signalName, currentValue, previousValue, recordedAt, count } ] } ] } ] } ] } ]
```

Bucket thiếu `bucketTime` bị bỏ; FE sắp xếp tăng dần theo `bucketTime`.

#### `GET /api/utility/export`

- Trả file Excel (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`), FE nhận `ResponseType.bytes`.
- Tên file lấy từ header `Content-Disposition` (hỗ trợ `filename*=UTF-8''...`, có/không dấu ngoặc kép); FE loại bỏ ký tự đường dẫn. Không có → `utility-signal-health.xlsx`.

---

### 7.7 Solar

File: [solar_api.dart](lib/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_solar/api/solar_api.dart)

| Endpoint | Query | Response |
|---|---|---|
| `GET /api/solar/monthly` | `facId`, `month` (`yyyyMM`) | `{ solarKwh, gridKwh, solarSharePercent, todayCo2Ton, todayEquivalentTrees }` |
| `GET /api/solar/detail` | `facId`, `month` (`yyyyMM`) | `{ summary { currentPowerKw, solarKwh, gridKwh, totalKwh, solarSharePercent }, dailyTrend [{ date, solarKwh, gridKwh, totalKwh }], costImpact { normalCostUsd, solarCostUsd, savingUsd, savingPercent }, environmentalImpact { co2Ton, equivalentTrees, co2Factor } }` |
| `GET /api/solar/hourly` | `facId`, `date` (`yyyy-MM-dd`) | `{ date, facId, facilities [{ facId, totalHours, totalKwh, peakKwh, peakHour, hours [{ hour, kwh }] }] }` |

---

### 7.8 SETTING (`/api/v1/...`)

Dùng chung helper [setting_api_support.dart](lib/utility_dashboard/utility_dashboard_setting/setting_api_support.dart): timeout riêng **30s**/request; GET phải trả mảng, POST/PUT phải trả object. Khi tạo/sửa, FE **bỏ field `id` khỏi body** (id nằm trên path với PUT).

#### SCADA — `/api/v1/utility-scada`

File: [utility_scada_api.dart](lib/utility_dashboard/utility_dashboard_setting/scada/api/utility_scada_api.dart)

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/v1/utility-scada` | — | `UtilityScada[]` |
| POST | `/api/v1/utility-scada` | `UtilityScada` (không `id`) | `UtilityScada` |
| PUT | `/api/v1/utility-scada/{id}` | `UtilityScada` (không `id`) | `UtilityScada` |

`UtilityScada`: `id, scadaId, fac, plcIp, plcPort, pcName, wlan, connected, alert, timeUpdate`

#### Channel — `/api/v1/utility-scada-channels`

File: [utility_scada_channel_api.dart](lib/utility_dashboard/utility_dashboard_setting/channel/api/utility_scada_channel_api.dart)

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/v1/utility-scada-channels` | — | `UtilityScadaChannel[]` |
| GET | `/api/v1/utility-scada-channels/group-by-fac` | — | Cây `[{ fac, scadaId, boxes: [{ boxId, devices: [{ channelId, cate, boxDeviceId }] }] }]` |
| POST | `/api/v1/utility-scada-channels` | `UtilityScadaChannel` (không `id`) | `UtilityScadaChannel` |
| PUT | `/api/v1/utility-scada-channels/{id}` | `UtilityScadaChannel` (không `id`) | `UtilityScadaChannel` |

`UtilityScadaChannel`: `id, scadaId, cate, boxDeviceId, boxId`

#### Para — `/api/v1/utility-para`

File: [utility_para_api.dart](lib/utility_dashboard/utility_dashboard_setting/para/api/utility_para_api.dart)

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/v1/utility-para/grouped-by-fac-with-paras` | — | Cây như channel, mỗi device thêm `paras: [UtilityPara]` |
| POST | `/api/v1/utility-para` | `UtilityPara` (không `id`) | `UtilityPara` |
| PUT | `/api/v1/utility-para/{id}` | `UtilityPara` (không `id`) | `UtilityPara` |

`UtilityPara`: `id, boxDeviceId, plcAddress, valueType, unit, cateId, nameVi, nameEn, isImportant, isAlert, minAlert, maxAlert`

---

### 7.9 API ngoài — Weather

[weather_api_service.dart](lib/weather_widgets/weather/api/weather_api_service.dart) gọi trực tiếp OpenWeatherMap (`/data/2.5/weather`, `units=metric`, tọa độ cố định của nhà máy) bằng package `http` để hiển thị hiệu ứng mưa trên MAP. Model đọc `weather, rain, sys, main, wind`.

---

## 8. Xử lý lỗi & timeout

| Khu vực | Timeout | Thông báo lỗi |
|---|---|---|
| Mặc định (`DioClient`) | connect 30s / receive 90s / send 30s (không áp trên Web) | Log interceptor ở debug |
| Water check, Power usage | receive 30s | Power usage: `message` trong body 400, hoặc `... failed (HTTP xxx)` / `Cannot reach the server` |
| Electric consumption | receive 60s | Như Power usage |
| Minute chart controller | request 15s | — |
| SETTING | receive/send 30s | 400/409/422 → `message` / `error` / `detail` trong body; timeout → `Request timed out`; không kết nối → `Cannot reach server`; còn lại → `Unexpected error (HTTP xxx)` |

Response sai kiểu (vd. mong object nhưng nhận mảng) → `FormatException` / `DioException(badResponse)`.

---

## 9. Test

```bash
flutter test
```

| File | Nội dung |
|---|---|
| [test/polling/polling_coordinator_test.dart](test/polling/polling_coordinator_test.dart) | `PollingCoordinator` (dùng `fake_async`) |
| [test/json_read_test.dart](test/json_read_test.dart) | Helper `jsonDouble` / `jsonInt` / `jsonText` |
| [test/electric_consumption_model_test.dart](test/electric_consumption_model_test.dart) | Parse model Electric consumption, kỳ hóa đơn (`billMonthOf`), kỳ không có dữ liệu, ngày dở, field `partial` / `coveragePct` / `completeDays`, trung bình trên ngày đủ |
| [test/consumption_chart_hover_test.dart](test/consumption_chart_hover_test.dart) | Hover chart (MWh / K$, chart thấp 200px) không gây RenderFlex overflow |
| [test/consumption_detail_table_test.dart](test/consumption_detail_table_test.dart) | Bảng Detail: nhãn nhóm không bị cắt khi cuộn, kéo chuột / nút ◀ ▶, mở tại ngày hiện tại + nút *Today*, cột Total / Avg ghim, đơn giá trong bảng K$ |
| [test/period_basis_formatter_test.dart](test/period_basis_formatter_test.dart) | `Calendar month · <from> – <to>`: tháng hiện tại (MTD), tháng đã qua, tháng 2 năm nhuận, tháng 12, giờ nhà máy UTC+7 |
| [test/widget_test.dart](test/widget_test.dart) | Widget test mặc định — **đang lỗi biên dịch trên VM** (app import `dart:js_interop`, chỉ có trên web) |

Chạy toàn bộ trừ `widget_test.dart` (PowerShell):

```powershell
flutter test (Get-ChildItem test -Recurse -Filter *_test.dart | ? Name -ne 'widget_test.dart' | % FullName)
```

---

## 10. Lưu ý / vấn đề đã biết

- **API key OpenWeatherMap đang hard-code** trong `weather_api_service.dart` và bị build vào bundle web. Nên chuyển sang `--dart-define` hoặc gọi qua backend, đồng thời thay key mới.
- `main.dart` đang bật `showPerformanceOverlay: true` — nên tắt trước khi build production.
- `build_web.bat` hard-code thư mục deploy `D:\Viet\Utility\BUILD_WEB`.
- `test/widget_test.dart` không chạy được bằng `flutter test` (VM) vì app dùng thư viện chỉ có trên web (`dart:js_interop`, package `web`).
- **SUMMARY / Solar (tháng dương lịch) và Bill period (kỳ hóa đơn 21 → 20) cho số khác nhau là đúng** — xem [5.1](#51-bill-period).
- Bill period: API chưa trả danh sách meter thiếu theo ngày (chỉ có số meter); thông tin đầu sheet Excel (số hiệu biến áp, Solar Lot, tỷ giá) chưa có trong API nên UI chưa hiển thị.
- Định dạng thời gian khác nhau giữa các API — chú ý khi thêm endpoint mới:
  - `series/history`: ISO-8601 **có offset** (`+07:00`)
  - `signal-health/history/hourly`: ISO local **không** zone
  - `period-dashboard`: `yyyyMMdd`; `energy-daily`, `monthly-summary`, `solar/monthly|detail`: `yyyyMM`
  - `power-usage`, `solar/hourly`: `yyyy-MM-dd`; `electric-consumption`: `yyyy-MM`

### Thêm API mới

1. Tạo `api/<name>_api.dart` trong module, nhận `Dio` (mặc định `DioClient.dio`), không hard-code base URL.
2. Model `fromJson` trong `models/`, kiểm tra kiểu response (`is Map` / `is List`).
3. Nếu cần tự làm mới: thêm interval vào `DashboardPollingIntervals`, id vào `PollingTaskIds`, đăng ký task với `PollingScope` phù hợp trong `utility_dashboard_screen.dart`.
4. Cập nhật bảng endpoint trong README này.
