#!/usr/bin/env python3

"""

Filter to anonymize email addresses. It reads input line by line,
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
import inspect
from urllib.parse import parse_qs
import hashlib
import hmac

logger = logging.getLogger(__name__)

# BIG FAT NOTICE on emails and regular expressions:
# If you're planning on using a regular expression to validate an email: don't. Emails
# are much more complex than you would imagine and most regular expressions will not
# cover all use cases. Newer RFCs even allow for international (read: UTF-8) email addresses.
# Most of your favorite programming languages will have a dedicated library for validating
# addresses.
#
# This pattern below, should, however match anything that remotely looks like an email.
# It is too broad, though, as it will match things which are not considered valid email
# addresses as well. But for our use case, that's OK and more than sufficient.
EMAIL_CATCH_ALL_PATTERN = '([^ "\\[\\]<]+|".+")@(\[([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[A-Za-z0-9]+:.+)\]|([^ \\{}():;>]+(\.[^ \\{}():;]+)*))'
EMAIL_CATCH_ALL = re.compile(EMAIL_CATCH_ALL_PATTERN)
EMPTY_RESPONSE = json.dumps({})

"""A default filter, if none other is provided."""
DEFAULT_FILTER_CLASS: str = 'SmartFilter'

"""Map filter names to friendly names"""
FILTER_MAPPINGS = {
    'default': DEFAULT_FILTER_CLASS,
    'smart': 'SmartFilter',
    'paranoid': 'ParanoidFilter',
    'noop': 'Filter',
    'hash': 'HashFilter',
}

"""
Helper function to check if the provided value is truthy or falsy.
Will throw an error on unknown values.
"""
def is_truthy(val: any, name: str) -> bool:
    if val is None:
        raise ValueError(f"Cannot evaluate empty (None) value for {name}")
    if val == True:
        return True
    elif val == False:
        return False

    val = str(val).lower()
    if val == 'y' or val == 'yes' or val == 't' or val == 'true' or val == '1':
        return True
    elif val == 'n' or val == 'no' or val == 'f' or val == 'false' or val == '0':
        return False

    raise ValueError(f"Cannot evaluate value '{val}' for {name}")

# -------------------------------------------------------------------------------- #

"""
Abstract base for all filters. Does nothing.
"""
class Filter():
    MESSAGE_ID_LINE = "message-id="
    MESSAGE_ID_LINE_LEN = len(MESSAGE_ID_LINE)

    def init(self, args: 'dict[str, list[str]]') -> None:
        pass

    def is_message_id(self, match: re.match, msg: str) -> bool:
        start = match.start()
        email = match.group()

        # Note that our regex will match things like "message-id=Issue1649523226559@postfix-mail.mail-system.svc.cluster.local"
        # so we need to filter / check for these first

        if email.startswith(self.MESSAGE_ID_LINE):
            return True
        
        if start >= self.MESSAGE_ID_LINE_LEN:
            pos = start-1
            while True:
                char = msg[pos]
                if char == '=':
                    break
                elif char in '{<["\'':
                    pos = pos - 1
                    continue

                return False

            check = msg[pos-self.MESSAGE_ID_LINE_LEN+1:pos+1]
            if check == self.MESSAGE_ID_LINE:
                return True

        return False

    def replace(self, match: re.match, msg: str) -> str:
        return match.group()

    def processMessage(self, msg: str) -> typing.Optional[str]:
        result = EMAIL_CATCH_ALL.sub(
            lambda x: self.replace(x, msg), msg
        )
        return json.dumps({'msg': result}, ensure_ascii=False) if result != msg else EMPTY_RESPONSE

# -------------------------------------------------------------------------------- #

"""
This filter will take an educated guess at how to best mask the emails, specifically:

* It will leave the first and the last letter of the local part (if it's oly one letter, it will get repeated)
* If the local part is in quotes, it will remove the quotes (Warning: if the email starts with a space, this might look weird in logs)
* It will replace all the letters in between with **ONE** asterisk
* It will replace everything but a TLD with a star
* Address-style domains will see the number replaced with stars

E.g.:

* `demo@example.org` -> `d*o@*******.org`
* `john.doe@example.solutions` -> `j*e@*******.solutions`
* `sa@localhost` -> `s*a@*********`
* `s@[192.168.8.10]` -> `s*s@[*.*.*.*]`
* `"multi....dot"@[IPv6:2001:db8:85a3:8d3:1319:8a2e:370:7348]` -> `m*t@[IPv6:*]`

This filter should still allow you to grep for lines relating to a specific email, if you know the original email, but you won't
be able to extract the original email back from the log.

"""
class SmartFilter(Filter):
    mask_symbol: str = '*'

    def init(self, args: 'dict[str, list[str]]') -> None:
        if 'mask_symbol' in args and len(args['mask_symbol']) > 0:
            self.mask_symbol = args['mask_symbol'][0]

        super().init(args)

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
                return '[' + self.mask_symbol + '.' + self.mask_symbol + '.' + self.mask_symbol + '.' + self.mask_symbol + ']'
        elif '.' in domain: # Normal domain
            s, tld = domain.rsplit('.', 1)
            return len(s) * self.mask_symbol  + '.' + tld
            pass
        else: # Local domain
            return len(domain) * self.mask_symbol

    def replace(self, match: re.match, msg: str) -> str:
        email = match.group()

        # Return the details unchanged if they look like Postfix message ID
        if self.is_message_id(match, msg):
            return email

        # The "@" can show up in the local part, but shouldn't appear in the
        # domain part (at least not that we know).
        local, domain = email.rsplit("@", 1)

        local = self.mask_local(local)
        domain = self.mask_domain(domain)

        return local + '@' + domain

# -------------------------------------------------------------------------------- #

"""
Paranoid filter is an extension of the smart filter. It will replace everything in the
local part with the `mask_symbol` and will leavel only top level domain (TLD) in the
domain part. Domain will be replaced by ONE occurence of the `mask_symbol`.

E.g.:

* `demo@example.org` -> `*@*.org`
* `john.doe@example.solutions` -> `*@*.solutions`
* `sa@localhost` -> `*@*`
* `s@[192.168.8.10]` -> `*@[*]`
* `"multi....dot"@[IPv6:2001:db8:85a3:8d3:1319:8a2e:370:7348]` -> `*@[IPv6:*]`
"""
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

# -------------------------------------------------------------------------------- #

"""
HashFilter will replace the email with its hash. This should allow you to grep through
the logs by hashing the email address yourself, while retaining the anonymity.

HashFilter uses HMAC to hash addresses (SHA256), so make sure you inject your unique salt. 
This way, the calculated hashes will be different accross organizations, though providing
complete anonymity.

Notice that for IP addresses hashes are not appropriate, the set of IP addresses is 
limited and rainbow tables could be used to get back IP addresses. This is not possible
with emails.

IANAL, though, so your mileage my vary.

"""
class HashFilter(Filter):
    prefix: str = ''            # Prefix emails with this (set of) character(s) for easier grepping
    suffix: str = ''            # Suffix emails with this (set of) character(s) for easier grepping
    case_sensitive: bool = True  # Convert strings to lowercase if false
    short_sha: bool = False      # Cut the string to first 8 characters
    split: bool = False          # Split and anonymize local and domain part independently
    
    def init(self, args: 'dict[str, list[str]]') -> None:
        if 'salt' in args and len(args['salt']) > 0:
            self.salt_encoded = args['salt'][0].encode()
        else:
            raise ValueError("You need to specify salt with this filter!")

        if 'prefix' in args and len(args['prefix']) > 0:
            self.prefix = args['prefix'][0]
        if 'suffix' in args and len(args['suffix']) > 0:
            self.suffix = args['suffix'][0]
        if 'case_sensitive' in args and len(args['case_sensitive']) > 0:
            self.case_sensitive = is_truthy(args['case_sensitive'][0], 'case_sensitive')
        if 'short_sha' in args and len(args['short_sha']) > 0:
            self.short_sha = is_truthy(args['short_sha'][0], 'short_sha')
        if 'split' in args and len(args['split']) > 0:
            self.split = is_truthy(args['split'][0], 'split')

        super().init(args)

    def replace(self, match: re.match, msg: str) -> str:
        email = match.group()

        # Return the details unchanged if they look like Postfix message ID
        if self.is_message_id(match, msg):
            return email

        if not self.case_sensitive:
            email = email.lower()

        if self.split:
            # The "@" can show up in the local part, but shouldn't appear in the
            # domain part (at least not that we know).
            local, domain = email.rsplit("@", 1)

            local = hmac.new(self.salt_encoded, local.encode(), hashlib.sha256).hexdigest()
            domain = hmac.new(self.salt_encoded, domain.encode(), hashlib.sha256).hexdigest()

            if self.short_sha:
                local = local[:8]
                domain = domain[:8]

            email = local + "@" + domain

        else:
            email = hmac.new(self.salt_encoded, email.encode(), hashlib.sha256).hexdigest()
            if self.short_sha:
                email = email[:8]

        return self.prefix + email + self.suffix


# -------------------------------------------------------------------------------- #

def get_filter() -> Filter:
    """
    Initialize the filter

    This method will check your configuration and create a new filter

    :return: Returns a specific implementation of the `Filter`
    """
    opts: dict[str, list[str]] = {}
    clazz: typing.Optional[str] = None

    if len(sys.argv) > 1:
        clazz = sys.argv[1].strip()
        # opts = sys.argv[2:]
        if '?' in clazz:
            clazz, query_string = clazz.split("?", 1)
            opts = parse_qs(query_string, keep_blank_values=True,strict_parsing=True)

        if clazz.lower() in FILTER_MAPPINGS:
            clazz = FILTER_MAPPINGS[clazz.lower()]

    if clazz is None or clazz.strip() == '':
        clazz = DEFAULT_FILTER_CLASS

    logger.debug(f"Constructing new {clazz} filter.")

    try:
        # Basic validation of names to avoid injection via crafted module/class strings
        # Only allow simple Python identifiers for class name and dotted module names.
        import re as _re

        if "." in clazz:
            module_name, class_name = clazz.rsplit(".", 1)

            if not _re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*", module_name):
                raise RuntimeError(f"Invalid module name '{module_name}'")
            if not _re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", class_name):
                raise RuntimeError(f"Invalid class name '{class_name}'")

            module = importlib.import_module(module_name)
            filter_class = getattr(module, class_name, None)
        else:
            class_name = clazz
            if not _re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", class_name):
                raise RuntimeError(f"Invalid class name '{class_name}'")

            filter_class = getattr(sys.modules[__name__], class_name, None)

        if filter_class is None:
            raise RuntimeError(f'Could not find filter named "{clazz}"!')

        if not inspect.isclass(filter_class):
            raise RuntimeError(f'Filter "{clazz}" is not a class')

        if not issubclass(filter_class, Filter):
            raise RuntimeError(f'Filter "{clazz}" is not a subclass of Filter')

        filter_obj: Filter = filter_class()

        # Ensure the instantiated object is actually a Filter instance
        if not isinstance(filter_obj, Filter):
            raise RuntimeError(f'Filter "{clazz}" is not an instance of Filter')
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
