"""Generate bundled GOwallet themes reproducibly; never edit installed themes."""
import json
import zipfile
import base64

from go_brand_assets import GO_SVG


def build_go_themes(root):
    (root / 'assets/in_app_logo_icons/electrum-wallet.svg').write_text(GO_SVG, encoding='utf-8')
    for mode in ('light', 'dark'):
        dark = mode == 'dark'
        with zipfile.ZipFile(root / f'asset_sources/default_themes/bitfinite/{mode}.zip') as source:
            files = {name: source.read(name) for name in source.namelist()}
        theme = json.loads(files['theme.json'])
        theme.update(version=45, name=f'GOwallet {mode.title()}')
        c = theme['colors']
        accent = '0xff45e0b5' if dark else '0xff087b63'
        bg = '0xff101a18' if dark else '0xfff3f6f4'
        surface = '0xff1b2925' if dark else '0xffffffff'
        text = '0xffedf5f1' if dark else '0xff152b24'
        muted = '0xffa6bbb1' if dark else '0xff586e63'
        for key in ('numpad_back_default', 'accent_color_blue', 'button_back_primary', 'button_back_border', 'switch_bg_on', 'checkbox_bg_checked', 'radio_button_border_enabled', 'radio_button_icon_border', 'radio_button_icon_enabled', 'radio_button_icon_circle', 'bottom_nav_icon_icon_highlighted', 'step_indicator_bg_lines', 'favorite_star_active', 'info_item_icons', 'custom_text_button_enabled_text', 'button_text_borderless', 'button_text_border', 'step_indicator_icon_text', 'step_indicator_icon_number'):
            c[key] = accent
        for key in ('background', 'background_app_bar'):
            c[key] = bg
        for key in ('popup_bg', 'info_item_bg', 'text_field_default_bg', 'currency_list_item_bg', 'bottom_nav_back', 'settings_item_level_two_active_bg', 'number_back_default', 'sw_bg', 'sw_mid', 'rate_type_toggle_color_off'):
            c[key] = surface
        for key in ('text_dark_one', 'text_dark_two', 'top_nav_icon_primary', 'button_text_secondary', 'text_field_active_text', 'number_text_default', 'bottom_nav_text', 'info_item_text', 'checkbox_text_label', 'text_confirm_total_amount', 'settings_item_level_two_active_text', 'radio_button_text_enabled'):
            c[key] = text
        for key in ('text_dark_three', 'text_subtitle_one', 'text_subtitle_two', 'text_field_default_text', 'text_field_active_label', 'info_item_label', 'radio_button_label_enabled', 'text_field_default_search_icon_left', 'text_field_default_search_icon_right'):
            c[key] = muted
        c.update(button_text_primary='0xff122421' if dark else '0xffffffff', button_back_secondary='0xff2c4037' if dark else '0xffe2ebe5', text_field_active_bg='0xff243930' if dark else '0xffeaf2ed', text_field_default_border='0xff547668' if dark else '0xff809b8e', accent_color_green=accent, settings_icon_back='0xff2c4037' if dark else '0xffe2ebe5')
        for key, color in [('scash', '#087b63'), ('shibacoin', '#b96a19'), ('dingocoin', '#b17c30'), ('bitfinite', '#2258e6')]:
            c['coin'][key] = '0xff' + color[1:]
            # BFX project artwork is a coin icon, distinct from the app brand.
            asset_name = 'bfx' if key == 'bitfinite' else key
            icon = f'svg/coin_icons/{asset_name}-go.svg'
            # Preserve the coin project's exact published mark. SVG is a layout
            # wrapper required by the inherited icon renderer, not a vector redraw.
            png = base64.b64encode((root / f'asset_sources/gowallet/{asset_name}.png').read_bytes()).decode()
            files['assets/' + icon] = f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100 100"><image x="2" y="2" width="96" height="96" xlink:href="data:image/png;base64,{png}"/></svg>'.encode()
            for slot in ('icons', 'images', 'secondaries'):
                # Upstream theme schema uses images_secondary for some versions.
                if slot in theme['assets']['coins']:
                    theme['assets']['coins'][slot][key] = icon
            for slot in theme['assets']['coins']:
                if isinstance(theme['assets']['coins'][slot], dict):
                    theme['assets']['coins'][slot][key] = icon
        files['assets/svg/gowallet.svg'] = GO_SVG.encode()
        theme['assets']['stack'] = 'svg/gowallet.svg'
        theme['assets']['stack_icon'] = 'svg/gowallet.svg'
        for key in ('coin_placeholder', 'persona_incognito', 'persona_easy', 'theme_preview'):
            theme['assets'][key] = 'svg/gowallet.svg'
        # Remove inherited coin branding, mascot artwork and theme previews.
        for name in list(files):
            if any(part in name.lower() for part in ('bitfinite', 'stack-icon', 'stack.svg', 'persona-', 'png/light-mode', 'png/dark-mode')):
                del files[name]
        files['theme.json'] = json.dumps(theme, ensure_ascii=False, indent=2).encode()
        with zipfile.ZipFile(root / f'assets/default_themes/{mode}.zip', 'w', zipfile.ZIP_DEFLATED) as output:
            for name, data in sorted(files.items()):
                output.writestr(zipfile.ZipInfo(name, (2026, 9, 6, 0, 0, 0)), data, compress_type=zipfile.ZIP_DEFLATED)
