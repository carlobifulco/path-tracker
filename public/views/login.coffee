$(document).ready =>

  #CHECKIN LOGIC
  #-------------

  redirect_to_main=()->
    window.location.href="/"

  check_result=(r)->
    #alert(r.ok)
    if r.ok==false or r.ok=="false"
      $("#bad_login").html("BAD LOGIN")
    else
      redirect_to_main()
      #unless to avoid ethernal login loop




  check_login=()=>
    username=$("#login_username").val()
    password=$("#login_password").val()
    data=
      password: password
      username: username
    url="/login"
    $.post(url,data).done((e)->
      e=JSON.parse(e)
      console.log ("r=#{e}")
      if e==true
        console.log "TRUE"
        redirect_to_main()
      if e==false
        alert ("Invalid Login.  Try Again"))

  set_new_user=(user,password)->
    localStorage.user=user
    localStorage.password=password
    redirect_to_main()


  new_account=()->
    console.log("create account ")
    user=$("#account_username").val()
    password= $("#account_password").val()
    url="/create_user/#{user}"
    url=encodeURI(url)
    p=$.post(url,{"password":password,"type":"json"})
    p.done(()->set_new_user(user,password))
    p.error(()->$("#bad_login").html("Pre-existing username; select a different username"))



  # check login
  window.check_login=check_login
  window.new_account=new_account

  #buttons


  $("#login_button").click(check_login)

