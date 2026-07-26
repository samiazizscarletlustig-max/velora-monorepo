# 🔌 INTEGRATION POINT: إعدادات متصفح Playwright لتخطي الحظر (يعتمد على وكيل مستخدم واقعي وتخطي اكتشاف البوتات)
import os
import asyncio
from playwright.async_api import async_playwright, Browser, Page

async def create_stealth_page(browser: Browser) -> Page:
    """
    Creates a new Playwright page with stealth settings.
    We avoid using heavy stealth packages if simple header manipulation suffices (Zero-Budget).
    """
    context = await browser.new_context(
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
        viewport={"width": 1920, "height": 1080},
        java_script_enabled=True,
        bypass_csp=True,
    )
    
    page = await context.new_page()
    
    # Simple stealth scripts to hide playwright properties
    await page.add_init_script("""
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined
        });
    """)
    
    return page

