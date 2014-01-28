Peer Tools
==========

Tools for peer correcting.

Usage :
-------

This tool requires your access to intra.42.fr and dashboard.42.fr.

At first use, you will be invited to enter your credentials (your real 42 credentials). If you want to, your credentials can be saved to a file for easy further usage.

Options :
---------

- Clone remaining corrections
  Clones all your remaining corrections
- Get phone numbers of corrections
  Displays phone numbers and locations of your corrections
- Get phone numbers of correctors
  Displays phone numbers and locations of your correctors
- Stalk people with their ids
  Displays phone numbers and locations of the given ids
- Clean corrections folders
  Does "make fclean" in all subdirectories of your corrections folder

Version 2 :
-----------

The second version of Peer Tools (29/01/14) was rewritten from scratch.
Error handling has been improved. They are clearer and most error cases are now supported.
Multiple projects handling has been added (either for git clones or phone numbers searching).
Curl is now used instead of wget, which increases compatibility.
The source code is clearer and each function is commented for better maintainability.

Suggestions / Bugs :
--------------------

For suggestions or bug reports, you can contact me on jabber (jlejeune), or send me an email (jlejeune@student.42.fr).

I love coffee too. O_O

License :
---------

Peer Tools is available under the [GNU General Public License, version 3](LICENSE).
