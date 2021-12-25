require 'sinatra'
require 'digest/md5'
require 'active_record'
require 'mail'
require 'openssl'
require 'recaptcha'
#ymlつくる
ActiveRecord::Base.configurations=YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection :development
ActiveRecord::Base.default_timezone = :local
set :environment, :production
set :sessions,
    expire_after: 7200,
    secret: 'abcdefjhij0123456789'


Recaptcha.configure do |config|
    config.site_key  = '6LetYQAcAAAAAGjrh2w2cBq_mm8BEUzFozZwZn0B'
    config.secret_key = '6LetYQAcAAAAAIa8d7skdjSyx3JQXI7yCCYw6Lt_'
    end
include Recaptcha::Adapters::ControllerMethods
include Recaptcha::Adapters::ViewMethods

class Member < ActiveRecord::Base
end
class Question < ActiveRecord::Base
end
class Rank < ActiveRecord::Base
end




get '/' do
    $trans4=0
    redirect '/login'
end
get '/login' do
    erb :loginscr2 #まずはログインさせる
end

get '/register' do #新規会員登録UI
    erb :register2
end

post '/register2' do #新規会員登録中身
    
    regi_address=params[:uname1]
    regi_rawpasswd=params[:pass1]
    #もう一つのDBに書き込む
    if Member.find_by(address: regi_address)!=nil
        redirect '/already'
    end

    if verify_recaptcha #ReCAPTCHA通ってから
    r=Random.new
    salt=Digest::MD5.hexdigest(r.bytes(20))
    hashed=Digest::MD5.hexdigest(salt+regi_rawpasswd)
    l=Member.new
    l.address=regi_address
    l.salt=salt
    l.hashed=hashed
    l.countquiz=0
    l.countcorrect=0
    l.save #これで会員登録完了
    redirect '/login'
    else
        redirect '/register'
    end
end

post '/auth' do
    trial_address=params[:uname]
    trial_passwd=params[:pass]
    begin
    f=Member.find(trial_address)
    db_address=f.address
    db_salt=f.salt
    db_hashed=f.hashed
    rescue=>e
        puts "cccc"
        redirect '/failure'
        #exit(-1)
    end
    trial_hashed=Digest::MD5.hexdigest(db_salt+trial_passwd)

    if db_hashed==trial_hashed
        insi=[*'A'..'Z', *'a'..'z', *0..9].shuffle[0..6].join #ワンタイムパスワード生成
        f.onetime=insi
        l=Time.now+3600*3
        f.expired_at=l
        f.countcorrect=0
        f.countquiz=0
        db_onetimeexpire=f.expired_at #expireする時間決まる
        db_onetime=f.onetime #ここまででパスワード
        #puts db_onetime
        options={ :address =>"localhost",
            :port =>25,
            :authentication => :nil,
            :openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE,
            :enable_starttls_auto => true }

        body="Try this password and login!!"
        body=body+"\n"
        body=body+"Your onetime password is #{insi}\n\n"
        body=body+"This password will be expired 3H later.\n"
        body=body+"You didn't try to login? \n report->18420@g.nagano-nct.ac.jp"
        mail=Mail.new
        mail.from="simplebbsservice@gmail.com"
        mail.to=trial_address #データベースのメアドを指定
        mail.cc=""
        mail.bcc=""
        mail.subject="Thank you for your login"
        mail.body=body
        mail.date=Time.now
        mail.charset="utf-8"
        mail.delivery_method(:smtp,options)
        mail.deliver

        $trans=db_onetime
        $trans2=db_onetimeexpire
        $trans3=db_address
        $trans4=1
        redirect '/auth2'
    else #単純にパスワードがちげえ
        session[:login_flag]=false
        redirect '/failure'
    end
end

get '/auth2' do
    if $trans4==0
        erb :badrequest
    else
    erb :twofacta2
    end
end

post '/auth3' do
    #puts $trans
    a=Time.now
    if $trans==params[:onetimepass]&&$trans2>a #2段階認証のやつと一緒か 有効期限内か
        session[:login_flag]=true
        #f.onetime=nil #ワンタイムパスワードの中身を消す
        redirect '/contentspage' 
    elsif $trans2<a 
        redirect '/expired'
    else #一緒じゃないから最初からやり直しとかいうクソ仕様（要改善）
        session[:login_flag]=false
        #puts "aaaa"
        redirect '/failure'
    end
end

get '/failure' do
    erb :failure
end

get '/expired' do
    erb :expired
end
get '/already' do
    erb :already
end

get '/contentspage' do
    if session[:login_flag]==true
        erb :index
    else
        erb :badrequest
    end
end

get '/ranking' do
    @s=Rank.all.order(countCorrect: "desc")
    erb :ranking
end

post '/quiz' do 
    r=Random.rand(1..10) #1-10の乱数を生成
    $rr=r
    puts r
    f=Member.find($trans3)
    #puts f.countquiz #できてない
    if f.countquiz<11  #なぜnilなの
        @s=Question.find(r) #乱数に合う問題を探す   ここができてない
        erb :question
    else #if they answered over 10
        redirect '/end'
    end
end

post '/ans' do
    ans=params[:answer] #answer word
    @n=""
    f=Member.find($trans3)

    if ans==(Question.find($rr)).correct #通らないならグローバル変数しかない？
        f.countcorrect+=1 #correct ++
        @n="正解!!"
    else
        @n="不正解!!"
    end

    f.countquiz+=1
    f.save
    erb :an
end

get '/end' do
    l=Rank.new
    f=Member.find($trans3)
    b=Time.now
    ab=$trans3.dup
    ab.sub!(/\@.*/m,"")
    l.user_id=ab #rankingデータベースについて 学籍番号がPRIMARYだと何回も同じ人がやった場合にnot uniqueのためだめ
    l.countCorrect=f.countcorrect
    l.time=b 
    l.token=[*'A'..'Z', *'a'..'z', *0..9].shuffle[0..6].join 

    f.countcorrect=0
    f.countquiz=0
    l.save
    redirect '/contentspage'
end










