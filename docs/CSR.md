# CSR mini tutorial

I've created 3 groups for myself to test with and I've put them in the "./csr-files" folder in this repo.

For you to create you own groups:

    $ touch csr.cnf

Edit your csr.cnf file and add:

'''
[ req ]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = <common-name>
O = <group-name>

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
Collap
'''

Notes:

There's great resources explaining the above elements for a csr file. I don't want to detract from this with all that info, but I do recommend doing some googling on csr and what these settings refer to.

What you need to change in the csr example above:

'''
[ dn ]
CN = <common-name>
O = <group-name>
'''

Replace the <common-name> and the <group-name> (dont have these <...> they're just indicating that this is a placeholder, these values should be only string characters).

# Another option

You can also generate a csr...