The theme being used for the site is a modification on top of
[`even`](https://www.getzola.org/themes/even/) pulled
on 2021-08-13, and then modified. Modifications are listed below.

1. Pick more reasonable font defaults in `_header.scss` and
   `site.scss` (_specifically_ remove "Cursive" which seems to pick
   Comic Sans on Windows).

2. Add support for automatically picking up page summaries if not
   defined within the particular post.

3. Improve tags and categories pages to look nicer

4. Added support for showing author, approval committee, and
   categories/tags in pages.

5. Added support for automatically handling URL linking for author and
   committee members. This includes picking up committee members urls
   from simply provided names.

6. Auto-centering of images

7. Added support for explicitly named "Areas" rather than
   categories.

8. Set up quote authors to stay closer to the actual quotes.

9. Added automated checks to ensure that areas are part of the
   expected set of areas.
