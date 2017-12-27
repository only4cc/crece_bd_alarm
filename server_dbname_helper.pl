#
# Objetivo: Obtiene los nombres de las Bases de Datos (con el tag "mssql") en un servidor especifico
#

use strict;
use warnings;

use Search::Elasticsearch;
use Config::Tiny;
use Data::Dumper::GUI;
 

my $GUI = 0 || shift;
my $DEBUG      = 1;
my $MAX_POINTS = 1000;

print "Obteniendo lista de servidores ...\n" if $DEBUG;

my $config = Config::Tiny->new;
$config = Config::Tiny->read( 'crece_alarm.conf' );
		
# Parametros de busqueda
my $serverid   = $config->{principal}->{serverid}  || '*';   # '*' Todos los servers
my $index_name = $config->{principal}->{indexname};  
my $nodo       = $config->{principal}->{nodos} || 'http://10.36.16.151:9200/';   # lab  # 'http://srv0018.e-contact.cl:9200/';   # dev


my $e = Search::Elasticsearch->new( nodes => [ $nodo, ] );
my $query = "crec_bd";

# Ejecuta la consulta 
my $results = $e->search(
    index => $index_name,
	size => $MAX_POINTS,
    body  => {
        query => {
            query_string => { "query" => $query  }
        }
    }
);

print Dumper($results) if $GUI;

# Recorre respuesta, llena observaciones para calculo estad. y despliega
my %puntos;
my $dbname;
my $message;
my @tok;
print "Resultado de la consulta : $query\n" if $DEBUG;
foreach (my $i=0; $i< scalar @{$results->{hits}->{hits} }; ++$i ) {
	#$serverid = $results->{hits}->{hits}->[$i]->{_source}->{beat}->{hostname};
	#$dbname   = $results->{hits}->{hits}->[$i]->{_source}->{dbid} || 'NULL';
    $message  = $results->{hits}->{hits}->[$i]->{_source}->{message}; 
#	print $serverid ."\t" . $dbname if $DEBUG;
#	print $message if $DEBUG;
    @tok = split(/,/,$message);
    $serverid = $tok[1];
    $dbname   =$tok[2];
	$puntos{ $serverid."|".$dbname } = 1 if ( $serverid and $dbname );
}

foreach my $k ( keys %puntos ) {
	print $k."\n";
}
