{ config, ... }:
{
  services.glance = {
    enable = true;
    settings = {
      pages = [
        {
          center-vertically = true;
          columns = [
            {
              size = "full";
              widgets = [
                {
                  autofocus = true;
                  type = "search";
                  search-engine = "google";
                }
                {
                  type = "group";
                  widgets = [
                    {
                      type = "hacker-news";
                      sort-by = "best";
                      limit = 15;
                      collapse-after = 5;
                    }
                    {
                      type = "lobsters";
                      sort-by = "hot";
                      limit = 15;
                      collapse-after = 5;
                    }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "calendar";
                  first-day-of-week = "monday";
                }
                {
                  type = "weather";
                  location = "Wrocław, Poland";
                  units = "metric";
                  hour-format = "24h";
                  hide-location = true;
                }
              ];
            }
          ];
          hide-desktop-navigation = true;
          name = "Startpage";
          width = "slim";
        }
      ];
    };
  };

  services.nginx.virtualHosts."start.kamoshi.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.glance.settings.server.port}";
    };
  };
}
