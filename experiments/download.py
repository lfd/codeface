import argparse
import glob
import urllib.request
import os
import shutil

from datetime import datetime


def arguments():
    """Command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--mbox_source", required=True,
                        help="Mailing list archive, currently supports: gnu")
    parser.add_argument("--list_name", required=True,
                        help="Mailing list name in the archive, e.g. qemu-devel")
    parser.add_argument("--save_path", required=True,
                        help="Local path to the directory to store the mailboxes")
    parser.add_argument("--start_year", required=True, 
                        help="Year to start querying the mailing list archive")
    parser.add_argument("--end_year", required=True, 
                        help="Year to end querying the mailing list archive")
    parser.add_argument("--concat", required=False, action="store_true",
                        help="Concat all mailboxes to a single archive")
    parser.add_argument("--rm", required=False, action="store_true",
                        help="Remove individual mailboxes after concatenating")
    return parser.parse_args()


def download_mbox_gnu(list_name, save_path, start_year, end_year):
    """Downloads mailboxes from the GNU mailing lists archive."""
    mbox_base = "https://lists.gnu.org/archive/mbox/" + list_name + "/"
    years = range(start_year, end_year+1)
    months = range(1, 12+1)

    for y in years:
        for m in months:
            postfix = str(y)+"-"+str(m).zfill(2)
            mbox_url =  urllib.parse.urljoin(mbox_base, postfix)
            mbox_path = os.path.join(save_path, list_name+"_"+postfix+".mbox")
            print("Downloading: " + mbox_url + " ...")
            try:
                urllib.request.urlretrieve(mbox_url, mbox_path)
                print("- Done")
            except:
                print("- Could not retrieve mailbox for " + postfix)


def concat_mbox(list_name, save_path, start_year, end_year, rm):
    """Concats all mailboxes found in the given directory."""

    print("Merging mailboxes ...")
    out_path = os.path.join(save_path, list_name+".mbox")
    years = range(start_year, end_year+1)
    months = range(1, 12+1)

    with open(out_path, "wb") as out_file:
        for y in years:
            for m in months:
                postfix = str(y)+"-"+str(m).zfill(2)
                mbox_path = os.path.join(save_path, list_name+"_"+postfix+".mbox")
                if os.path.exists(mbox_path):
                    with open(mbox_path, 'rb') as box_file:
                        shutil.copyfileobj(box_file, out_file)
                    if rm:
                        os.remove(mbox_path)
    print("- Done")


def main(mbox_source, list_name, save_path, start_year, end_year, concat, rm):
    # Clean output directory.
    if os.path.exists(save_path):
        shutil.rmtree(save_path)
    os.makedirs(save_path)

    if mbox_source == "gnu":
        download_mbox_gnu(list_name, save_path, start_year, end_year)
    if concat:
        concat_mbox(list_name, save_path, start_year, end_year, rm)


if __name__ == "__main__":
    args = arguments()
    main(args.mbox_source, args.list_name, args.save_path, int(args.start_year), int(args.end_year), args.concat, args.rm)
