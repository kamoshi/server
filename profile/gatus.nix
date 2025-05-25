{ ... }:
{

  services.gatus = {
    enable = true;

    settings = {
      web.port = 3456;

      endpoints = [
        {
          name = "Website";
          url = "https://kamoshi.org/";
          interval = "5m";
          conditions = [
            "[STATUS] == 200"
          ];
        }
        {
          name = "Auth";
          url = "https://auth.kamoshi.org/status";
          interval = "5m";
          conditions = [
            "[STATUS] == 200"
            "[BODY] == true"
          ];
        }
        {
          name = "Miniflux";
          url = "https://rss.kamoshi.org/healthcheck";
          interval = "5m";
          conditions = [
            "[STATUS] == 200"
          ];
        }
        {
          name = "Forgejo";
          url = "https://git.kamoshi.org/api/healthz";
          interval = "5m";
          conditions = [
            "[STATUS] == 200"
            "[BODY].status == pass"
            "[BODY].checks.cache:ping[0].status == pass"
            "[BODY].checks.database:ping[0].status == pass"
          ];
        }
      ];
    };
  };

  services.nginx.virtualHosts."status.kamoshi.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3456";
    };
  };
}
