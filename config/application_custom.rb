module Consul
  class Application < Rails::Application
    # Idioma por defecto
    config.i18n.default_locale = :es

    # Idiomas disponibles
    available_locales = [:es]

    # Ruta por defecto que utilizará la aplicación
    config.root_directory = "/presupuestosparticipativos"
  end
end
