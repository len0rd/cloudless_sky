#!/usr/bin/env python3
# My build script
# based off of makelove (https://github.com/pfirsich/makelove)
from pathlib import Path
import os, sys, shutil, subprocess
import zipfile
from typing import List
import toml

from lovebuilder.filelist import FileList


def git_ls_tree(path=".", visited=None) -> List[Path]:
    """
    Get a list of all files tracked by git
    """
    p = os.path

    if visited == None:
        visited = set()
    rpath = p.realpath(path)
    if rpath in visited:
        sys.exit("Symlink loop detected!")
    else:
        visited.add(rpath)

    ls_tree = (
        subprocess.check_output(
            ["git", "ls-tree", "-r", "--name-only", "HEAD"], cwd=path
        )
        .decode("utf-8")
        .splitlines()
    )
    out = []
    for item in ls_tree:
        item_path = p.join(path, item)
        if p.islink(item_path) and p.isdir(item_path):
            out.extend(git_ls_tree(item_path, visited))
        else:
            out.append(Path(item_path))
    return out


def assemble_game_directory(love_files: List[str], game_directory: Path):
    """
    Build the list of files to place in the build directory, then copy them over
    """
    if game_directory.exists():
        shutil.rmtree(game_directory)
    game_directory.mkdir(parents=True, exist_ok=True)
    file_list = FileList(".")
    for rule in love_files:
        if rule == "+::git-ls-tree::" or rule == "::git-ls-tree::":
            ls_tree = git_ls_tree(".")
            for item in ls_tree:
                try:
                    file_list.include_raw(item)
                except FileNotFoundError:
                    sys.exit("Could not find git-tracked file '{}'".format(item))
        elif rule[0] == "-":
            file_list.exclude(rule[1:])
        elif rule[0] == "+":
            file_list.include(rule[1:])
        else:
            file_list.include(rule)

    for fname in file_list:
        dest_path = game_directory / fname
        dest_path.parents[0].mkdir(parents=True, exist_ok=True)
        shutil.copyfile(fname, dest_path)


def create_love_file(game_dir: Path, love_file_path: Path):
    """
    Create the game's .love file. `.love` files are just zips with a different extension
    """
    love_archive = zipfile.ZipFile(love_file_path, "w")
    files = [f for f in game_dir.glob("**/*") if f.is_file()]
    for path in files:
        arcname = os.path.normpath(os.path.relpath(path, game_dir))
        love_archive.write(path, arcname=arcname)
    love_archive.close()


def main():
    with open("make.toml", "r") as f:
        config = toml.load(f)

    build_dir_base = Path.cwd() / config["build_directory"]
    build_dir_base.mkdir(parents=True, exist_ok=True)
    love_dir = build_dir_base / "love"
    temp_game_dir = love_dir / "game_directory"
    love_file_name = love_dir / f"{config["name"]}.love"
    assemble_game_directory(config["love_files"], temp_game_dir)
    create_love_file(temp_game_dir, love_file_name)
    shutil.rmtree(temp_game_dir)


if __name__ == "__main__":
    main()
