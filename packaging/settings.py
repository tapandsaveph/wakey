from pathlib import Path

root = Path(defines['root'])
application = defines['app']
notice = defines['notice']
files = [application, notice]
symlinks = {'Applications': '/Applications'}
hide = [Path(notice).name]
background = str(root / 'background.png')
format = 'UDZO'
filesystem = 'HFS+'
window_rect = ((160, 160), (720, 420))
default_view = 'icon-view'
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 15
label_pos = 'bottom'
arrange_by = None
icon_locations = {'Wakey.app': (180, 235), 'Applications': (540, 235)}
include_icon_view_settings = True
include_list_view_settings = False
