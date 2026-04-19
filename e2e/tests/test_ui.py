"""无头浏览器 E2E：验证 /ui/ 经 React 注水后的真实 DOM（需先有 API + DB）。"""

from __future__ import annotations

import os
from urllib.parse import urljoin

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


def _base_url() -> str:
    return os.environ.get("E2E_BASE_URL", "http://127.0.0.1:8080").rstrip("/")


@pytest.fixture(scope="session")
def driver():
    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--window-size=1280,900")
    opts.add_argument("--remote-allow-origins=*")

    chrome_bin = os.environ.get("CHROME_BINARY")
    if chrome_bin:
        opts.binary_location = chrome_bin

    drv = webdriver.Chrome(options=opts)
    try:
        yield drv
    finally:
        drv.quit()


@pytest.fixture()
def ui_url() -> str:
    return urljoin(_base_url() + "/", "ui/")


def test_home_heading_and_sections(driver, ui_url):
    driver.get(ui_url)

    wait = WebDriverWait(driver, 20)
    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "h1")))
    h1 = driver.find_element(By.CSS_SELECTOR, "h1")
    assert "API + PostgreSQL" in h1.text

    lede = driver.find_element(By.CSS_SELECTOR, ".lede")
    assert "/ui" in lede.text or "/health" in lede.text


def test_sections_contain_expected_json(driver, ui_url):
    driver.get(ui_url)

    wait = WebDriverWait(driver, 20)

    def three_sections_loaded(drv):
        bodies = drv.find_elements(By.CSS_SELECTOR, ".section-body")
        if len(bodies) < 3:
            return False
        return all("加载中" not in b.text for b in bodies[:3])

    wait.until(three_sections_loaded)

    bodies = driver.find_elements(By.CSS_SELECTOR, ".section-body")
    texts = [b.text for b in bodies[:3]]

    assert any('"status"' in t and "ok" in t for t in texts)
    assert any("PostgreSQL" in t for t in texts)
    assert any("Hello from PostgreSQL" in t for t in texts)
