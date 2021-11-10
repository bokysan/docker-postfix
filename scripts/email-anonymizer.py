#!/usr/bin/env python3

"""

Filter to anonyimize email addresses. It reads input line by line,
finds all emails in the input and masks them using given filter.

Big thanks to [Sergio Del Río Mayoral](https://github.com/sdelrio)
for the concept and the idea, although not a lot of the code went
into this commit in the end.

"""

import re
import logging
import typing
import json
import sys
import importlib

logger = logging.getLogger(__name__)

# BIG FAT NOTICE on emails and regular expressions:
# If you're planning on using a regular expression to validate an email: don't. Emails
# are much more complext than you would imagine and most regular expressions will not
# cover all usecases. Newer RFCs even allow for international (read: UTF-8) email addresses.
# Most of your favourite programming languages will have a dedicated library for validating
# addresses.
#
# This pattern below, should, however match (hopefully) anything that looks like an email
# It is too broad, though, as it will match things which are not considered valid email
# addresses as well. But for our use case, that's OK and more than sufficient.
EMAIL_CATCH_ALL_PATTERN = '([^ "\\[\\]<>]+|".+")@(\[([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[A-Za-z0-9]+:.+)\]|([^ \\{}():;]+(\.[^ \\{}():;]+)*))'
EMAIL_CATCH_ALL = re.compile(EMAIL_CATCH_ALL_PATTERN)
EMPTY_RESPONSE = json.dumps({})

# Postfix formats message IDs like this. Let's not mask them
# 20211207101128.0805BA272@31bfa77a2cab
MESSAGE_ID_PATTERN = '[0-9]+\.[0-9A-F]+@[0-9a-f]+'
MESSAGE_ID = re.compile(MESSAGE_ID_PATTERN)

"""A default filter, if none other is provided."""
DEFAULT_FILTER_CLASS: str = 'SmartFilter'

"""Map filter names to friendly names"""
FILTER_MAPPINGS = {
    'default': DEFAULT_FILTER_CLASS,
    'smart': 'SmartFilter',
    'paranoid': 'ParanoidFilter',
    'noop': 'NoopFilter',
}

# ---------------------------------------- #

class Filter():
    def init(self, args: list[str]) -> None:
        pass

    def processMessage(self, msg: str) -> str:
        pass

"""
This filter does nothing.
"""
class NoopFilter(Filter):
    def processMessage(self, msg: str) -> str:
        return EMPTY_RESPONSE

"""
This filter will take an educated guess at how to best mask the emails, specifically:

* It will leave the first and the last letter of the local part (if it's oly one letter, it will get repated)
* If the local part is in quotes, it will remove the quotes (Warning: if the email starts with a space, this might look weird in logs)
* It will replace all the letters inbetween with **ONE** asterisk
* It will replace everything but a TLD with a star
* Address-style domains will see the number replaced with stars

E.g.:

* `demo@example.org` -> `d*o@*******.org`
* `john.doe@example.solutions` -> `j*e@*******.solutions`
* `sa@localhost` -> `s*a@*********`
* `s@[192.168.8.10]` -> `s*s@[*]`
* `"multi....dot"@[IPv6:2001:db8:85a3:8d3:1319:8a2e:370:7348]` -> `m*t@[IPv6:*]`

"""
class SmartFilter(Filter):
    mask_symbol: str = '*'

    def mask_local(self, local: str) -> str:
        if local[0] == '"' and local[-1] == '"':
            return local[:2] + self.mask_symbol + local[-2:]
        else:
            return local[0] + self.mask_symbol + local[-1]

    def mask_domain(self, domain: str) -> str:
        if domain[0] == '[' and domain[-1] == ']': # Numerical domain
            if ':' in domain[1:-1]:
                left, right = domain.split(":", 1)
                return left + ':' + (len(right)-1) * self.mask_symbol + ']'
            else:
                return '[*.*.*.*]'
        elif '.' in domain: # Normal domain
            s, tld = domain.rsplit('.', 1)
            return len(s) * self.mask_symbol  + '.' + tld
            pass
        else: # Local domain
            return len(domain) * self.mask_symbol

    def replace(self, match: re.match) -> str:
        email = match.group()

        # Return the details unchanged if they look like Postfix message ID
        if bool(MESSAGE_ID.match(email)):
            return email

        # The "@" can show up in the local part, but shouldn't appear in the
        # domain part (at least not that we know).
        local, domain = email.rsplit("@", 1)

        local = self.mask_local(local)
        domain = self.mask_domain(domain)

        return local + '@' + domain

    def processMessage(self, msg: str) -> typing.Optional[str]:
        result = EMAIL_CATCH_ALL.sub(
            lambda x: self.replace(x), msg
        )
        return json.dumps({'msg': result}, ensure_ascii=False) if result != msg else EMPTY_RESPONSE

class ParanoidFilter(SmartFilter):

    def mask_local(self, local: str) -> str:
        return self.mask_symbol

    def mask_domain(self, domain: str) -> str:
        if domain[0] == '[' and domain[-1] == ']': # Numerical domain
            if ':' in domain[1:-1]:
                left, right = domain.split(":", 1)
                return left + ':*]'
            else:
                return '[*]'
        elif '.' in domain: # Normal domain
            s, tld = domain.rsplit('.', 1)
            return self.mask_symbol  + '.' + tld
            pass
        else: # Local domain
            return self.mask_symbol

# ---------------------------------------- #

def get_filter() -> Filter:
    """
    Initialize the filter

    This method will check your configuration and create a new filter

    :return: Returns a specific implementation of the `Filter`
    """
    opts: list[str] = []
    clazz: typing.Optional[str] = None

    if len(sys.argv) > 1:
        clazz = sys.argv[1].strip()
        opts = sys.argv[2:]

        if clazz.lower() in FILTER_MAPPINGS:
            clazz = FILTER_MAPPINGS[clazz.lower()]

    if clazz is None or clazz.strip() == '':
        clazz = DEFAULT_FILTER_CLASS

    logger.debug(f"Constructing new {clazz} filter.")

    try:
        if "." in clazz:
            module_name, class_name = clazz.rsplit(".", 1)
            filter_class = getattr(importlib.import_module(module_name), class_name)
            filter_obj: Filter = filter_class()
        else:
            filter_class = getattr(sys.modules[__name__], clazz)
            filter_obj: Filter = filter_class()
    except Exception as e:
        raise RuntimeError(f'Could not instatiate filter named "{clazz}"!') from e

    try:
        filter_obj.init(opts)
    except Exception as e:
        raise RuntimeError(f'Init of filter "{clazz}" with parameters {opts} failed!') from e

    return filter_obj


def process(f: Filter) -> None:
    while True:
        message = sys.stdin.readline()
        if message:
            message = message[:-1] # Remove line feed
            result = f.processMessage(message)
            print(result)
            sys.stdout.flush()
        else:
            # Empty line. stdin has been closed
            break

process(get_filter())