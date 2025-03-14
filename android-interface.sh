#!/bin/bash

shopt -s extglob

SCR_NAME_EXEC=$0
SCR_NAME_EXEC_FP=$(realpath "$0")
SCR_NAME=$(basename "$SCR_NAME_EXEC")
SCR_NAME=${SCR_NAME%.*}
RVB_DIR=$HOME/rvx-builder

COLOR_OFF='\033[0m'
COLOR_RED='\033[1;31m'

help_info() {
  cat <<EOF
Usage: $SCR_NAME [command] [options]

Commands:
  run                          Launches the rvx-builder.
                               Running $SCR_NAME_EXEC without arguments will
                               assume this command (i.e. will run the
                               builder)
    --delete-cache
    --dc                       Deletes revanced/ before running builder
    --delete-cache-no-keystore
    --dcnk                     Deletes revanced/ before running builder, but
                               preserving keystore file.
    --delete-cache-after
    --dca                      Deletes revanced/ after running builder
    --delete-cache-after-no-keystore
    --dcank                    Deletes revanced/ after running builder, but
                               preserving keystore file

  reinstall                    Delete everything and start from scratch.
    --delete-keystore          Also delete the signature file. This will
                               make ReVanced use a different signature,
                               which will not allow you to install an
                               updated build over the previously installed
                               one (you'll need to uninstall that first)

  update                       Update the builder to the latest version

  help                         Display this help info
EOF
}

log() {
  echo -e "[$SCR_NAME] $1"
}

error() {
  log "$1"
  [[ "$2" == y ]] && help_info
  exit "${3:-1}"
}

set_alias() {
  echo "alias rvx='./rvx-builder.sh run'" >> ../usr/etc/bash.bashrc
  echo "alias rvxre='./rvx-builder.sh reinstall && ./rvx-builder.sh run'" >> ../usr/etc/bash.bashrc
  echo "alias rvxup='./rvx-builder.sh update && ./rvx-builder.sh run'" >> ../usr/etc/bash.bashrc
  echo "alias opon='nano rvx-builder/options.json'" >> ../usr/etc/bash.bashrc
}

dload_and_install() {
  log "Downloading rvx-builder..."
  curl -sLo rvx-builder.zip https://github.com/inotia00/rvx-builder/archive/refs/heads/revanced-extended.zip
  log "Unzipping..."
  unzip -qqo rvx-builder.zip
  rm rvx-builder.zip
  mv rvx-builder-revanced-extended/{.[!.]*,*} .
  log "Installing packages..."
  npm install --omit=dev
  rmdir rvx-builder-revanced-extended
  [[ -z "$1" ]] && log "Done. Execute \`$SCR_NAME_EXEC run\` to launch the builder."
}

preflight() {
  setup_storage() {
    [[ ! -d "$HOME"/storage ]] && {
      log "You will now get a permission dialog to allow access to storage."
      log "This is needed in order to move the built APK (+ MicroG) to internal storage."
      sleep 5
      termux-setup-storage
    } || {
      log "Already gotten storage access."
    }
  }

  install_dependencies() {
    [[ -f "$RVB_DIR/settings.json" ]] && {
      log "Node.js and JDK already installed."
      return
    }
    log "Updating Termux and installing dependencies..."
    pkg update -y
    pkg install nodejs-lts openjdk-17 -y || {
      error "$COLOR_RED
Failed to install Node.js and OpenJDK 17.
Possible reasons (in the order of commonality):
1. Termux was downloaded from Play Store. Termux in Play Store is deprecated, and has packaging bugs. Please install it from F-Droid.
2. Mirrors are down at the moment. Try running \`termux-change-repo\`.
3. Internet connection is unstable.
4. Lack of free storage.$COLOR_OFF" n 2
    }
  }
  
  setup_storage
  install_dependencies

  [[ ! -d "$RVB_DIR" ]] && {
    set_alias
    log "rvx-builder not installed. Installing..."
    mkdir -p "$RVB_DIR"
    cd "$RVB_DIR"
    dload_and_install n
  } || {
    log "rvx-builder found."
    log "All checks done."
    }
}

run_builder() {
  preflight
  termux-wake-lock
  echo
  [[ "$1" == "--delete-cache" ]] || [[ "$1" == "--dc" ]] && {
    delete_cache
  }
  [[ "$1" == "--delete-cache-no-keystore" ]] || [[ "$1" == "--dcnk" ]] && {
    delete_cache_no_keystore
  }
  cd "$RVB_DIR"
  node .
  [[ "$1" == "--delete-cache-after" ]] || [[ "$1" == "--dca" ]] && {
    delete_cache
  }
  [[ "$1" == "--delete-cache-after-no-keystore" ]] || [[ "$1" == "--dcank" ]] && {
    delete_cache_no_keystore
  }
  termux-wake-unlock
}

delete_cache() {
  # Is this even called a cache?
  log "Deleting builder cache..."
  rm -rf "$RVB_DIR"/revanced
}

delete_cache_no_keystore() {
  log "Deleting builder cache preserving keystore..."
  mv "$RVB_DIR"/revanced/revanced.keystore "$HOME"/revanced.keystore
  rm -rf "$RVB_DIR"/revanced
  mkdir -p "$RVB_DIR"/revanced
  mv "$HOME"/revanced.keystore "$RVB_DIR"/revanced/revanced.keystore
}

reinstall_builder() {
  log "Deleting rvx-builder..."
  [[ "$1" != "--delete-keystore" ]] && {
    [[ -f "$RVB_DIR/revanced/revanced.keystore" ]] && {
      mv "$RVB_DIR"/revanced/revanced.keystore "$HOME"/revanced.keystore
      log "Preserving the keystore. If you do not want this, use the --delete-keystore flag."
      log "Execute \`$SCR_NAME_EXEC help\` for more info."
    }
  }
  rm -r "$RVB_DIR"
  mkdir -p "$RVB_DIR"
  [[ -f "$HOME/revanced.keystore" ]] && {
    log "Restoring the keystore..."
    mkdir -p "$RVB_DIR"/revanced
    mv "$HOME"/revanced.keystore "$RVB_DIR"/revanced/revanced.keystore
  }
  log "Reinstalling..."
  cd "$RVB_DIR"
  dload_and_install
}

update_builder() {
  log "Backing up some stuff..."
  [[ -d "$RVB_DIR/revanced" ]] && {
    mkdir -p "$HOME"/revanced_backup
    mv "$RVB_DIR"/revanced/* "$HOME"/revanced_backup
  }
  [[ -f "$RVB_DIR/settings.json" ]] && {
    mv "$RVB_DIR"/settings.json "$HOME"/settings.json
  }
  log "Deleting rvx-builder..."
  rm -r "$RVB_DIR"
  log "Restoring the backup..."
  mkdir -p "$RVB_DIR"
  [[ -d "$HOME/revanced_backup" ]] && {
    mkdir -p "$RVB_DIR"/revanced
    mv "$HOME"/revanced_backup/* "$RVB_DIR"/revanced
  }
  [[ -f "$HOME/settings.json" ]] && {
    mv "$HOME"/settings.json "$RVB_DIR"/settings.json
  }
  log "Updating rvx-builder..."
  cd "$RVB_DIR"
  dload_and_install n
  run_self_update
}

run_self_update() {
  log "Performing self-update..."

  # Download new version
  log "Downloading latest version..."
  ! curl -sLo "$SCR_NAME_EXEC_FP".tmp https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh && {
    log "Failed: Error while trying to download new version!"
    error "File requested: https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh" n
  } || log "Done."

  # Copy over modes from old version
  OCTAL_MODE=$(stat -c '%a' "$SCR_NAME_EXEC_FP")
  ! chmod "$OCTAL_MODE" "$SCR_NAME_EXEC_FP.tmp" && error "Failed: Error while trying to set mode on $SCR_NAME_EXEC.tmp." n

  # Spawn update script
  cat > updateScript.sh << EOF
#!/bin/bash

# Overwrite old file with new
mv "$SCR_NAME_EXEC_FP.tmp" "$SCR_NAME_EXEC_FP" && {
  echo -e "[$SCR_NAME] Done. Execute '$SCR_NAME_EXEC run' to launch the builder."
  rm \$0
  } || {
  echo "[$SCR_NAME] Failed!"
  }
EOF

  log "Running update process..."
  exec /bin/bash updateScript.sh
}

main() {
  if [[ -z "$@" ]]; then
    run_builder
  elif [[ $# -gt 2 ]]; then
    error "2 optional arguments acceptable, got $#."
  else
    case $1 in
      run)
        run_builder "$2"
      ;;
      reinstall)
        reinstall_builder "$2"
      ;;
      update)
        update_builder
      ;;
      help)
        help_info
      ;;
      *)
        error "Invalid argument(s): $@."
      ;;
    esac
  fi
}

main $@
