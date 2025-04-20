{ config, pkgs, ... }:
{
  services.restic.backups = {
    daily = {
      # Add paths in modules
      paths = [];
      repository = "rclone:proton:/backup/kamoshi";
      initialize = true;
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];
      passwordFile = "/root/secret/rclone/password";
      rcloneConfigFile = "/root/secret/rclone/rclone.conf";
    };
  };
}
