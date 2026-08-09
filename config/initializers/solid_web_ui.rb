# config/initializers/solid_web_ui.rb

# Inherited Authentication
SolidWebUi::Queue.config.base_controller_class = "Admin::ApplicationController"
SolidWebUi::Cache.config.base_controller_class = "Admin::ApplicationController"
SolidWebUi::Cable.config.base_controller_class = "Admin::ApplicationController"

# Enclosed by admin.html.erb layout
SolidWebUi::Queue.config.layout = "admin"
SolidWebUi::Cache.config.layout = "admin"
SolidWebUi::Cable.config.layout = "admin"

# SolidWebUi.config.color_scheme = "light" # Default => "dark"
