# -*- coding: utf-8 -*-

"""

AWattPrice Config

"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

import copy
import os
import sys

from pathlib import Path
from typing import Optional, Tuple

from box import Box  # type: ignore
from configupdater import ConfigUpdater  # type: ignore
from loguru import logger as log

from .defaults import DEFAULT_CONFIG
from .utils import verify_file_permissions


def bootstrap_config(path: Optional[Path] = None) -> ConfigUpdater:
    """Create the Config file and populate it."""
    if path is None:
        path = Path(os.path.expanduser("~")) / ".config" / "awattprice" / "config.ini"
    if not path.parent.is_dir():
        os.makedirs(path.parent.as_posix())
    config_updater = ConfigUpdater()
    config_updater.read_string(DEFAULT_CONFIG)
    write_config_updater(path, config_updater)
    return config_updater


def config_updater_factory(config: Box) -> Tuple[Path, ConfigUpdater]:
    """Return a ConfigUpdater object and the path obj to the config file.

    Note, the config file must exist. There isn't too much error checking in this
    function. E. g. that will not work with an empty config file.
    """
    config_updater_data = copy.deepcopy(config)
    if "config_file_path" in config_updater_data:
        path = Path(config_updater_data.pop("config_file_path"))
    else:
        raise AttributeError("The config is missing the config_file_path. This should not happen.")

    config_updater = ConfigUpdater()
    to_add = []
    with open(path.as_posix()) as fh:
        config_updater.read_file(fh)
    for section in config_updater_data:
        if config_updater.has_section(section):
            config_updater_section = config_updater[section]
            last_option = config_updater_section.options()[-1]
            for option, value in config[section].items():
                if option in config_updater_section:
                    config_updater_section[option].value = value
                else:
                    config_updater_section[last_option].add_after.option(option, value)
                    last_option = option
            config_updater[section] = config_updater_section
        else:
            tmp_updater = ConfigUpdater()
            section_txt = f"[{section}]\n" + "\n".join(
                (f"{option}: {value}" for option, value in config_updater_data[section].items())
            )
            tmp_updater.read_string(section_txt)
            to_add.append(tmp_updater[section])
    if to_add:
        last_section = config_updater[config_updater.sections()[-1]]
        for section in to_add:
            # Add a new line for readability
            config_updater[last_section.name].add_after.space().section(section)
            last_section = section

    return path, config_updater


def write_config_updater(path: Path, config: ConfigUpdater) -> None:
    """Write the config file."""
    to_write_config = copy.deepcopy(config)
    with os.fdopen(os.open(path.as_posix(), os.O_WRONLY | os.O_CREAT, 0o600), "w") as fh:
        to_write_config.write(fh)


def read_config(path: Optional[Path] = None) -> Box:
    """Return the config"""
    config = Box(box_it_up=True)
    if path:
        config_path_locations: Tuple[Path, ...] = (path,)
    else:
        config_path_locations = (
            Path(Path("/etc") / "awattprice" / "config.ini"),
            Path(os.path.expanduser("~")) / ".config" / "awattprice" / "config.ini",
        )
    found_config_file = False
    for path in config_path_locations:
        if path.exists():
            found_config_file = True
            break
    else:
        log.info(f"No config file found in {path.parent}. Creating one...")
        path = Path(os.path.expanduser("~")) / ".config" / "awattprice" / "config.ini"
        config_updater = bootstrap_config(path)
    if path.parent.exists() and not path.parent.is_dir():
        log.error(f"Expected the config directory {path.parent} to be a directory.")
        sys.exit(1)

    if not verify_file_permissions(path):
        log.error(f"Could not ensure secure file permissions for {path}. Fix them and try again.")
        sys.exit(1)

    if found_config_file:
        config_updater = ConfigUpdater()
        try:
            config_updater.read(path.as_posix())
        except Exception as e:
            log.error(f"Could not read the config from {path}: {e}")
            sys.exit(1)

    config = Box(config_updater.to_dict(), box_dots=True)
    config["config_file_path"] = path

    # Strip off quotes that made it into the config.ini file
    config.file_location.data_dir = config.file_location.data_dir.strip("\"'")
    config.file_location.log_dir = config.file_location.log_dir.strip("\"'")
    config.file_location.apns_dir = config.file_location.apns_dir.strip("\"'")

    if config.notifications.use_sandbox.lower() == "true":
        # Convert use_sandbox string to bool
        run_on_sandbox = True
    elif config.notifications.use_sandbox.lower() == "false":
        run_on_sandbox = False
    else:
        log.error(
            "Please specify a valid bool (True or False) in config.notifications.use_sandbox"
            "Will use sandbox for this session."
        )
        run_on_sandbox = False

    config.notifications.use_sandbox = run_on_sandbox
    config.notifications.dev_team_id = config.notifications.dev_team_id.strip("\"'")
    config.notifications.apns_encryption_key_id = config.notifications.apns_encryption_key_id.strip("\"'")
    config.notifications.apns_encryption_key = config.notifications.apns_encryption_key.strip("\"'")

    return config
