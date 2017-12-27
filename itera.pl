#
# Utilitario para obtener todos los pares servidor, nombre de bd desde ES
#
            
my $dir = "C:\\Users\\Julio\\Dropbox\\current\\eContact\\crece_bd_alarm";
my $lista = "lista_iter.txt";
rename $lista, $lista."old";
system("perl server_dbname.pl > $dir\\$lista" );

open( my $FH, "< $lista" ) or die "Error, no se pudo leer $lista\\n$!";
my $l;
my @par;
while ( $l = <$FH> ) {
	chomp($l);
	@par=split(/\|/,$l);
	print "\n$l  => $par[0] \t $par[1]\n";
    system("perl crece_alarm.pl $par[0] $par[1]" ) if ( $par[0] and $par[1] );
}
close($FH);

