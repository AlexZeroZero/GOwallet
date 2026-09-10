"""One geometric master for the GOwallet SVG and Android vector assets."""
from pathlib import Path

INK = '#122421'
MINT = '#45E0B5'
# Scalable implementation of the user-selected D concept (2026-09-10).
# Open circular capital G and a detached upper-right ring, shared by Flutter,
# Android launcher, monochrome notification icon and both splash screens.
G = ('M88.5,47.5 C82,38.5 72.5,34 62,34 C43.2,34 28,49.2 28,68 '
     'C28,86.8 43.2,102 62,102 C80.8,102 96,86.8 96,68 '
     'V64 H58 V73 H86.5 C84.2,84.6 74.1,93 62,93 '
     'C48.2,93 37,81.8 37,68 C37,54.2 48.2,43 62,43 '
     'C69.9,43 76.8,46.7 81.5,52.5 Z')
RING = ('M107.5,35 C107.5,39.97 103.47,44 98.5,44 '
        'C93.53,44 89.5,39.97 89.5,35 C89.5,30.03 93.53,26 98.5,26 '
        'C103.47,26 107.5,30.03 107.5,35 Z '
        'M104.3,35 C104.3,31.8 101.7,29.2 98.5,29.2 '
        'C95.3,29.2 92.7,31.8 92.7,35 C92.7,38.2 95.3,40.8 98.5,40.8 '
        'C101.7,40.8 104.3,38.2 104.3,35 Z')
TILE = 'M37,3 H91 Q125,3 125,37 V91 Q125,125 91,125 H37 Q3,125 3,91 V37 Q3,3 37,3 Z'
RIM = 'M37,5 H91 Q123,5 123,37 V91 Q123,123 91,123 H37 Q5,123 5,91 V37 Q5,5 37,5 Z'

GO_SVG = f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs>
  <linearGradient id="jade" x1="15" y1="5" x2="114" y2="128" gradientUnits="userSpaceOnUse">
    <stop stop-color="#ACF5DB"/><stop offset=".46" stop-color="{MINT}"/><stop offset="1" stop-color="#20B994"/>
  </linearGradient>
  <linearGradient id="rim" x1="24" y1="6" x2="103" y2="122" gradientUnits="userSpaceOnUse">
    <stop stop-color="#E5FFF5" stop-opacity=".8"/><stop offset=".5" stop-color="#E5FFF5" stop-opacity=".12"/><stop offset="1" stop-color="{INK}" stop-opacity=".15"/>
  </linearGradient>
</defs>
<path d="{TILE}" fill="url(#jade)"/>
<path d="{RIM}" fill="none" stroke="url(#rim)" stroke-width="1"/>
<path d="{G}" fill="{INK}"/>
<path d="{RING}" fill="{INK}"/>
</svg>
'''


def vector(body, width=108, viewport=128):
    return (f'<vector xmlns:android="http://schemas.android.com/apk/res/android" '
            f'xmlns:aapt="http://schemas.android.com/aapt" android:width="{width}dp" '
            f'android:height="{width}dp" android:viewportWidth="{viewport}" '
            f'android:viewportHeight="{viewport}">{body}</vector>\n')


def mark(color=INK):
    return f'<path android:fillColor="{color}" android:pathData="{G}"/><path android:fillColor="{color}" android:pathData="{RING}"/>'


def jade(path):
    return f'''<path android:pathData="{path}"><aapt:attr name="android:fillColor">
<gradient android:startX="15" android:startY="5" android:endX="114" android:endY="128" android:type="linear">
<item android:offset="0" android:color="#ACF5DB"/><item android:offset="0.46" android:color="{MINT}"/><item android:offset="1" android:color="#20B994"/>
</gradient></aapt:attr></path>'''


TILE_VECTOR = jade(TILE) + f'''<path android:pathData="{RIM}" android:fillColor="#00000000" android:strokeWidth="1">
<aapt:attr name="android:strokeColor"><gradient android:startX="24" android:startY="6" android:endX="103" android:endY="122" android:type="linear">
<item android:offset="0" android:color="#CCE5FFF5"/><item android:offset="0.5" android:color="#1FE5FFF5"/><item android:offset="1" android:color="#26122421"/>
</gradient></aapt:attr></path>''' + mark()


def write_brand_assets(root: Path):
    def write(relative, content):
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding='utf-8', newline='\n')

    write('tool/flavors/electrum_wallet.svg', GO_SVG)
    write('tool/flavors/android/electrum_wallet_icon.xml', vector(TILE_VECTOR))
    write('assets/in_app_logo_icons/electrum-wallet.svg', GO_SVG)
    res = 'android/app/src/main/res/'
    write(res + 'drawable/electrum_wallet_icon.xml', vector(TILE_VECTOR))
    # Android 12 controls the outer splash canvas. Keep the actual mark 104dp,
    # fully inside its circular safe area and aligned with the Flutter launch.
    write(res + 'drawable/go_splash_icon.xml', vector(
        '<group android:translateX="92" android:translateY="92" android:scaleX="0.8125" android:scaleY="0.8125">' + TILE_VECTOR + '</group>', 288, 288))
    write(res + 'mipmap-anydpi/gowallet_launcher.xml', vector(TILE_VECTOR))
    write(res + 'drawable/go_launcher_background.xml', vector(jade('M0,0 H128 V128 H0 Z')))
    # All ink, including the detached ring, fits Android's 66/108 safe circle.
    foreground = '<group android:pivotX="64" android:pivotY="64" android:scaleX="0.70" android:scaleY="0.70">' + mark() + '</group>'
    write(res + 'drawable/go_launcher_foreground.xml', vector(foreground))
    write(res + 'drawable/go_launcher_monochrome.xml', vector(foreground))
    for qualifier in ('v26', 'v33'):
        mono = '<monochrome android:drawable="@drawable/go_launcher_monochrome"/>' if qualifier == 'v33' else ''
        write(res + f'mipmap-anydpi-{qualifier}/gowallet_launcher.xml',
              '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/go_launcher_background"/><foreground android:drawable="@drawable/go_launcher_foreground"/>' + mono + '</adaptive-icon>')
    write(res + 'drawable/app_icon_alpha.xml', vector(mark('#FFFFFFFF'), 24))


if __name__ == '__main__':
    write_brand_assets(Path(__file__).resolve().parents[1])
