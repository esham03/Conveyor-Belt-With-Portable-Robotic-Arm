/**
 * @file esp32_cam.ino
 * @brief Subsystem 5: Surveillance Camera Firmware (ESP32-CAM AI-Thinker)
 * @project Conveyor Belt with Portable Robotic Arm
 * @reference Government Polytechnic Panaji (Diploma Report 2024, Ch 4, pp. 52-54)
 * 
 * Hardware Architecture:
 * - Module: AI-Thinker ESP32-CAM (ESP32-S + 4MB PSRAM + OV2640 2MP Camera)
 * - Power Requirement: 5V DC @ >= 2A regulated rail (Dedicated Buck Converter)
 * - Features:
 *   - HTTP MJPEG Video Streamer on port 81 (or port 80 /stream)
 *   - On-board Flash LED control (GPIO 4)
 *   - Dual Wi-Fi Mode: Attempts Station mode; falls back to autonomous SoftAP
 *     ("ESP32-CAM-ROBOT") if local Wi-Fi is unreachable.
 *   - Zero hardcoded credentials in version control (uses secrets.h).
 */

#include "esp_camera.h"
#include <WiFi.h>
#include "esp_http_server.h"
#include "camera_pins.h"
#include "secrets.h"

#define CAMERA_MODEL_AI_THINKER

#define PART_BOUNDARY "esp32cam_mjpeg_boundary_polytechnic_panaji"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

httpd_handle_t stream_httpd = NULL;
httpd_handle_t camera_httpd = NULL;
bool flashState = false;

// --- HTTP REQUEST HANDLERS ---

/**
 * @brief Handler for root web console / snapshot preview
 */
static esp_err_t index_handler(httpd_req_t *req) {
  const char* html = 
    "<!DOCTYPE html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
    "<title>ESP32-CAM Video Monitor</title>"
    "<style>"
    "body{background:#0e1621;color:#e1e9f0;font-family:sans-serif;margin:0;padding:20px;text-align:center;}"
    "h1{color:#00e5ff;font-size:22px;margin-bottom:8px;}"
    ".sub{color:#8aa2b8;font-size:14px;margin-bottom:20px;}"
    ".stream-container{display:inline-block;border:2px solid #1a2736;border-radius:12px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.6);}"
    "img{max-width:100%;height:auto;display:block;}"
    ".btn{display:inline-block;padding:10px 20px;margin:10px 5px;background:#00e5ff;color:#0e1621;border:none;border-radius:6px;font-weight:bold;cursor:pointer;text-decoration:none;}"
    ".btn-flash{background:#ffb300;color:#000;}"
    "</style></head><body>"
    "<h1>Conveyor Automation Monitor</h1>"
    "<div class=\"sub\">Subsystem 5: ESP32-CAM AI-Thinker Surveillance Feed</div>"
    "<div class=\"stream-container\"><img src=\"/stream\"></div><br>"
    "<a class=\"btn btn-flash\" href=\"/flash?toggle=1\">Toggle LED Flash</a>"
    "<a class=\"btn\" href=\"/snapshot\" target=\"_blank\">Single Snapshot</a>"
    "</body></html>";

  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, html, strlen(html));
}

/**
 * @brief Handler for single JPEG snapshot
 */
static esp_err_t capture_handler(httpd_req_t *req) {
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }
  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=capture.jpg");
  esp_err_t res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
  esp_camera_fb_return(fb);
  return res;
}

/**
 * @brief Continuous MJPEG streaming handler
 */
static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t * _jpg_buf = NULL;
  char * part_buf[64];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) {
    return res;
  }

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      res = ESP_FAIL;
    } else {
      _jpg_buf_len = fb->len;
      _jpg_buf = fb->buf;
    }

    if (res == ESP_OK) {
      size_t hlen = snprintf((char *)part_buf, 64, _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, (const char *)part_buf, hlen);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    if (fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
      _jpg_buf = NULL;
    } else if (res != ESP_OK) {
      break;
    }
  }
  return res;
}

/**
 * @brief Toggle on-board flash LED
 */
static esp_err_t flash_handler(httpd_req_t *req) {
  flashState = !flashState;
  digitalWrite(LED_GPIO_NUM, flashState ? HIGH : LOW);
  httpd_resp_set_type(req, "text/plain");
  char buf[32];
  snprintf(buf, sizeof(buf), "FLASH_STATE:%d", flashState ? 1 : 0);
  return httpd_resp_send(req, buf, strlen(buf));
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;

  httpd_uri_t index_uri = {
    .uri       = "/",
    .method    = HTTP_GET,
    .handler   = index_handler,
    .user_ctx  = NULL
  };

  httpd_uri_t stream_uri = {
    .uri       = "/stream",
    .method    = HTTP_GET,
    .handler   = stream_handler,
    .user_ctx  = NULL
  };

  httpd_uri_t snap_uri = {
    .uri       = "/snapshot",
    .method    = HTTP_GET,
    .handler   = capture_handler,
    .user_ctx  = NULL
  };

  httpd_uri_t flash_uri = {
    .uri       = "/flash",
    .method    = HTTP_GET,
    .handler   = flash_handler,
    .user_ctx  = NULL
  };

  if (httpd_start(&camera_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(camera_httpd, &index_uri);
    httpd_register_uri_handler(camera_httpd, &stream_uri);
    httpd_register_uri_handler(camera_httpd, &snap_uri);
    httpd_register_uri_handler(camera_httpd, &flash_uri);
  }

  // Also bind port 81 specifically for direct stream consumers
  config.server_port = 81;
  config.ctrl_port = config.ctrl_port + 1;
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
  }
}

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(false);
  Serial.println(F("\n[ESP32-CAM] INITIALIZING FIRMWARE"));

  // Flash LED Setup
  pinMode(LED_GPIO_NUM, OUTPUT);
  digitalWrite(LED_GPIO_NUM, LOW);

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  // Frame parameters optimized for smooth stream latency
  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA;   // 640x480
    config.jpeg_quality = 12;
    config.fb_count = 2;
    config.grab_mode = CAMERA_GRAB_LATEST;
    Serial.println(F("[ESP32-CAM] PSRAM FOUND: USING VGA DUAL BUFFER"));
  } else {
    config.frame_size = FRAMESIZE_QVGA;  // 320x240
    config.jpeg_quality = 14;
    config.fb_count = 1;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
    Serial.println(F("[ESP32-CAM] NO PSRAM: USING QVGA SINGLE BUFFER"));
  }

  // Camera sensor initialize
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[ESP32-CAM] ERROR: Camera init failed 0x%x\n", err);
    return;
  }

  sensor_t * s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_vflip(s, 1);       // Invert sensor if camera mounted upside-down
    s->set_brightness(s, 1);
    s->set_saturation(s, 0);
  }

  // --- WI-FI CONNECTION SEQUENCE ---
  Serial.printf("[ESP32-CAM] Connecting to Wi-Fi SSID: %s\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  WiFi.setSleep(false);

  uint8_t wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 15) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(F("\n[ESP32-CAM] Wi-Fi CONNECTED (Station Mode)"));
    Serial.print(F("[ESP32-CAM] IP Address: "));
    Serial.println(WiFi.localIP());
  } else {
    // Fallback to Autonomous Access Point
    Serial.println(F("\n[ESP32-CAM] Wi-Fi Connection Timed Out. Spawning Access Point..."));
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASSWORD);
    Serial.print(F("[ESP32-CAM] SoftAP SSID: "));
    Serial.println(AP_SSID);
    Serial.print(F("[ESP32-CAM] SoftAP IP: "));
    Serial.println(WiFi.softAPIP());
  }

  startCameraServer();
  Serial.println(F("[ESP32-CAM] STREAM SERVER ACTIVE:"));
  Serial.print(F("  Web Console: http://"));
  Serial.print(WiFi.status() == WL_CONNECTED ? WiFi.localIP() : WiFi.softAPIP());
  Serial.println(F("/"));
  Serial.print(F("  Direct Stream: http://"));
  Serial.print(WiFi.status() == WL_CONNECTED ? WiFi.localIP() : WiFi.softAPIP());
  Serial.println(F(":81/stream"));
}

void loop() {
  // Web server runs asynchronously in background FreeRTOS task
  delay(10000);
}
