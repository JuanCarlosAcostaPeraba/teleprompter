from pathlib import Path


files = [defines["app"]]
symlinks = {"Applications": "/Applications"}
background = str(Path(defines["assets"]) / "installer-background.png")

filesystem = "HFS+"
format = "UDZO"
# The artwork occupies the top 410 points. Leave room for Finder bars
# that can still be visible when the user has enabled them globally.
window_rect = ((160, 110), (640, 536))
default_view = "icon-view"
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_tab_view = False
show_pathbar = False
icon_size = 96
text_size = 13
icon_locations = {"Teleprompter.app": (160, 179), "Applications": (480, 179)}
