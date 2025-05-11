{ config, pkgs, ... }:
let
  pathBackup = "/var/backup/postgres";
in
{
  services.postgresql = {
    enable = true;
  };

  systemd.tmpfiles.rules = [
    "d ${pathBackup} 0700 postgres postgres -"
  ];

  services.postgresqlBackup = {
    enable = true;
    # Add database names in modules
    databases = [];
    location = pathBackup;
    startAt = "*-*-* 23:15:00";
  };


  services.restic.backups.daily.paths = [
    pathBackup
  ];
}
