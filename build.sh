#!/bin/bash
(cd `dirname $0` && lime rebuild . ios -debug $@)
(cd `dirname $0` && lime rebuild . ios  $@)
(cd `dirname $0` && lime rebuild . mac -debug $@)
(cd `dirname $0` && lime rebuild . mac  $@)
