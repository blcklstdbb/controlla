#!/usr/bin/env python3

# Standard library imports
import os
import argparse


def file_check(file):
    """
    Checks the file extension.

    Args
        file
    Returns:
        file_extension (str): String containing the file extension
    """
    # unpacking the tuple
    file_name, file_extension = os.path.splitext(file)
    return file_extension


def mount_dmg(dmg):
    """

    :param dmg:
    :return:
    """
    # do stuff
    pass


def parse_pkg(pkg):
    """

    :param pkg:
    :return:
    """
    # file extension check
    file_ext = file_check(pkg)


def extract_app(app):
    """

    :param app:
    :return:
    """
    # do stuff
    pass


def extract_payloads(payload):
    """

    :param payload:
    :return:
    """
    # do stuff
    pass


def extract_pkg(pkg):
    """

    :param pkg:
    :return:
    """
    # do stuff
    pass


def main():
    """

    :return:
    """
    if args.dmg:
        mount_dmg(args.dmg)
    elif args.pkg:
        parse_pkg(args.pkg)
    elif args.app:
        extract_app(args.app)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Automated macOS installer extractor.')
    parser.add_argument('--pkg', '-p', dest='pkg', help='Package (.pkg) file.')
    parser.add_argument('--dmg', '-d', dest='dmg', help='Disk Image (.dmg) file.')
    parser.add_argument('--app', '-a', dest='app', help='Application (.app) file.')
    parser.add_argument('--folder', '-f', dest='directory', help='Destination directory.')
    args = parser.parse_args()
    main()
