if {$argc!=3} {
	puts "Usage: ns lab15_1.tcl TCPversion tcpTick1 tcpTick2."
	exit
}

set par1 [lindex $argv 0]
set par2 [lindex $argv 1]
set par3 [lindex $argv 2]

#产生一个仿真对象
set ns [new Simulator]

#打开记录文件，用来记录封包传送的过程
set nd [open out.tr w]
$ns trace-all $nd

#打开两个文件用来记录 FTP0 和 FTP1 的 cwnd 变化情况
set f0 [open cwnd0-rtt-$par1.tr w]
set f1 [open cwnd1-rtt-$par1.tr w]

#定义一个结束程序
proc finish { } \
{
	global ns nd f0 f1 tcp0 tcp1

    #显示最后的平均吞吐量
    puts [format "tcp0:\t%.1f kbps" [expr [$tcp0 set ack_]*([$tcp0 set packetSize_])*8/1000.0/40]]
    puts [format "tcp1:\t%.1f kbps" [expr [$tcp1 set ack_]*([$tcp1 set packetSize_])*8/1000.0/40]]

   $ns flush-trace

    close $nd
    close $f0
    close $f1

    exit 0
}


#定义一个记录的程序，每隔 0.01s 就去记录当时的 tcp0 和 tcp1 的 cwnd
proc record { } \
{
	global ns tcp0 f0 tcp1 f1
    set now [$ns now]
    puts $f0 "$now [$tcp0 set cwnd_]"
    puts $f1 "$now [$tcp1 set cwnd_]"
    $ns at [expr $now+0.01] "record"
}

#建立结点
set s0 [$ns node]
set s1 [$ns node]
set d0 [$ns node]
set d1 [$ns node]
set r0 [$ns node]
set r1 [$ns node]
set r2 [$ns node]

#建立链路
$ns duplex-link $s0 $r0 10Mb 1ms DropTail
$ns duplex-link $s1 $r0 10Mb 1ms DropTail
$ns duplex-link $r0 $r1 1.5Mb 40ms DropTail
$ns duplex-link $r1 $r2 1.5Mb 40ms DropTail
$ns duplex-link $r2 $d1 10Mb 1ms DropTail
$ns duplex-link $r2 $d0 10Mb 1ms DropTail

#设置队列长度为 32 个封包大小
set buffer_size 32
$ns queue-limit $r0 $r1 $buffer_size

#建立 FTP0 应用程序（RTT 较短）
if {$par1=="Tahoe"} {
	set tcp0 [new Agent/TCP]
    set tcpsink0 [new Agent/TCPSink]
} elseif {$par1=="Reno"} {
	set tcp0 [new Agent/TCP/Reno]
    set tcpsink0 [new Agent/TCPSink]
} elseif {$par1=="Newreno"} {
	set tcp0 [new Agent/TCP/Newreno]
    set tcpsink0 [new Agent/TCPSink]
} elseif {$par=="Sack"} {
	set tcp0 [new Agent/TCP/Sack1]
    set tcpsink0 [new Agent/TCPSink]
} else {
	set tcp0 [new Agent/TCP/Vegas]
	$tcp0 set v_alpha_ 1
	$tcp0 set v_beta_ 3
    set tcpsink0 [new Agent/TCPSink]
}


$tcp0 set packetSize_ 1024
$tcp0 set window_ 128
$tcp0 set tcpTick_ $par2
$tcp0 set fid_ 0
$ns attach-agent $s0 $tcp0
$tcpsink0 set fid_ 0
$ns attach-agent $d0 $tcpsink0

$ns connect $tcp0 $tcpsink0

set ftp0 [new Application/FTP]
$ftp0 attach-agent $tcp0

#建立 FTP1 应用程序（RTT 较长）
if {$par1=="Tahoe"} {
	set tcp1 [new Agent/TCP]
    set tcpsink1 [new Agent/TCPSink]
} elseif {$par1=="Reno"} {
	set tcp1 [new Agent/TCP/Reno]
    set tcpsink1 [new Agent/TCPSink]
} elseif {$par1=="Newreno"} {
	set tcp1 [new Agent/TCP/Newreno]
    set tcpsink1 [new Agent/TCPSink]
} elseif {$par=="Sack"} {
	set tcp1 [new Agent/TCP/Sack1]
    set tcpsink1 [new Agent/TCPSink]
} else {
	set tcp1 [new Agent/TCP/Vegas]
	$tcp0 set v_alpha_ 1
	$tcp0 set v_beta_ 3
    set tcpsink1 [new Agent/TCPSink]
}
$tcp1 set packetSize_ 1024
$tcp1 set window_ 128
$tcp1 set tcpTick_ $par3
$tcp1 set fid_ 0
$ns attach-agent $s1 $tcp1
$tcpsink1 set fid_ 1
$ns attach-agent $d1 $tcpsink1
$ns connect $tcp1 $tcpsink1

set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1


#在 0.0s 时，FTP0 和 FTP1 开始传送
$ns at 0.0 "$ftp0 start"
$ns at 0.0 "$ftp1 start"

#在 40.0s 时，FTP0 和 FTP1 结束传送
$ns at 40.0 "$ftp0 stop"
$ns at 40.0 "$ftp1 stop"

$ns at 0.0 "record"
$ns at 40.0 "finish"

$ns run
