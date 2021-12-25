require 'mail'
require "openssl"

options={ :address =>"localhost",
          :port =>25,
          :authentication => :nil,
          :openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
          :enable_starttls_auto => true }

body=""
body=body+"本文です。\n"
body=body+"2行目\n"
body=body+"3行目\n"

mail=Mail.new

mail.from="simplebbsservice2@gmail.com"
mail.to="18420@g.nagano-nct.ac.jp"
mail.cc=""
mail.bcc=""
mail.subject="適当"
mail.body=body
mail.date=Time.now
mail.charset="utf-8"
mail.delivery_method(:smtp,options)

mail.deliver