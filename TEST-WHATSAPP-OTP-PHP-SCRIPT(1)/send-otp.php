<?php
session_start();
echo $OTP=$_SESSION['OTP'];

$API="eb76c035d5d0a2bd2a0d0834b93c9c26"; // ENTER YOUR VALID API KEY HERE
$PHONE=$_POST['phone'];
$_SESSION['phone']=$PHONE;
$COUNTRY='91'; // Country Code

$URL="https://whatsapp.renflair.in/V1.php?API=$API&PHONE=$PHONE&OTP=$OTP&COUNTRY=$COUNTRY";
$curl=curl_init($URL);
curl_setopt($curl, CURLOPT_URL, $URL);
curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
$resp = curl_exec($curl);
curl_close($curl);
$data = json_decode($resp);
echo $resp;

header("location:otp.php");
?>
