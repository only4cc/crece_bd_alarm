#
# julio.trumper@gmail.com
# Objetivo: Alertar crecimientos "anomalos" de BD SQL Server con datos desde ELK
#           en base a la pendiente
#
use strict;
use warnings;

use Search::Elasticsearch;
use Date::Parse;
use DateTime::Format::Epoch;
use Statistics::Regression;
use Config::Tiny;

my $DEBUG      = 0;    # 1: Imprime info. adicional, mas verboso
my $MAX_POINTS = 1500; # (Aprox. 365 dias * cada 24 / 4 horas )

# Parametros de busqueda
my $serverid   = shift ;    # '*' Todos los servers
my $db_name    = shift ; 	# '*' Todas las BD o por ejemplo 'GSYS_CFG'; 

if ( ! $serverid or ! $db_name ) {
   die "Error, $0 <serverid> <dbname>\n"; 
}

my $config = Config::Tiny->new;
$config    = Config::Tiny->read( 'crece_alarm.conf' );
		
# Parametros de busqueda
my $nodo       = $config->{principal}->{nodos}     || 'http://srv0013.e-contact.cl:9200/';   # lab  # 'http://srv0018.e-contact.cl:9200/';   # dev
my $index_name = $config->{principal}->{indexname} || 'eco-72h-2017.10.25';   #Ejemplo
my $alarm_script = $config->{alarma}->{alarm_script};
my $pct_1      = $config->{alarma}->{pct1}  || 1.05;
my $pct_7      = $config->{alarma}->{pct7}  || 1.05;
my $pct_30     = $config->{alarma}->{pct30} || 1.05;

print "revisando servidor: [ $serverid ]  BD: [ $db_name ] en el indice: [ $index_name ]\n";

my $e = Search::Elasticsearch->new( nodes => [ $nodo, ] );
my $query = "mssql AND $db_name AND $serverid";
 
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

# Recorre respuesta, llena observaciones para calculo estad. y despliega
my %puntos;
my $db_size;
my ( $ts, $ts_epoch );
print "Consulta con condiciones: [ $query ]\n";
foreach (my $i=0; $i< scalar @{$results->{hits}->{hits}}; ++$i ) {
	if ( $DEBUG ) {
		print $results->{hits}->{hits}->[$i]->{_source}->{serverid} ."\t";
		print $results->{hits}->{hits}->[$i]->{_source}->{dbid} ."\t";
		print $results->{hits}->{hits}->[$i]->{_source}->{"\@timestamp"} ."\t";
	}
	$ts = $results->{hits}->{hits}->[$i]->{_source}->{"\@timestamp"};
	$ts_epoch = str2time($ts);
	$db_size = $results->{hits}->{hits}->[$i]->{_source}->{size_bd_MB};
	if ( $DEBUG ) {
		print $ts_epoch."\t";
		print  $db_size."\n";
	}
	$puntos{ $ts_epoch } = $db_size;
}

# Numero total de observaciones
my $num_obs = scalar (keys %puntos);
if ( $num_obs > 10 ) {
	1;
} 
else {
	print "[ $num_obs ] : Observaciones insuficientes\n";
	exit;
}
# Muestra Puntos a utilizar
if ( $DEBUG ) {
	sep();
	print "Puntos a utilizar:\n"; 
	for my $k ( keys %puntos ) {
		print "$k\t$puntos{$k}\n" if $DEBUG;
	}
}

#------------------------------------------------------------------------------------------
# Calcula Regresiones Lineales con Fecha (formato epoch) y Tamaño de la BD en MB

my $reg=Statistics::Regression->new( "Lineal de Crecimiento de BD Long-Term", ["Intercep.", "Pendiente"]); 

# Con todos los puntos slt (slope long-term)
my $cat=1;
for my $key ( keys %puntos ) {
    $reg->include( $puntos{$key}, [$cat, $key]);
}
my @theta  = $reg->theta();
my $slopeLT = $theta[1];
if ( $DEBUG ) {
	sep();

	print "\nToda la informacion\n";
	print "Intercep.: $theta[0] \n";
	print "Pendiente: $slopeLT \n";

	print "Nro. de Variables    : ".$reg->k()."\n";
	print "Nro. de Observaciones: ".$reg->n()."\n";   
	##print "R^2                  :". $reg->rsq()."\n";
	#$reg->print;
}

# Fecha mas antigua
my $last_epoch = (keys %puntos)[0];
my $dt_old = DateTime->new( year => 1970, month => 1, day => 1 );
my $formatter = DateTime::Format::Epoch->new(
                      epoch          => $dt_old,
                      unit           => 'seconds',
                      type           => 'int',    # o 'float', 'bigint'
                      skip_leap_seconds => 1,
                      start_at       => 0,
                      local_epoch    => undef,
                  );
$dt_old = $formatter->parse_datetime( $last_epoch );

# Con los puntos del ultimo mes s30 (slope)
my $last_epoch_30 = $last_epoch - ( 30 * 24 * 3600 );
my $dt = DateTime->new( year => 1970, month => 1, day => 1 );
my $formatter_30 = DateTime::Format::Epoch->new(
                      epoch          => $dt,
                      unit           => 'seconds',
                      type           => 'int',    # o 'float', 'bigint'
                      skip_leap_seconds => 1,
                      start_at       => 0,
                      local_epoch    => undef,
                  );
my $dt2 = $formatter_30->parse_datetime( $last_epoch_30 );
if ( $DEBUG ) {
	print "\nLast epoch: $last_epoch\n";
	print "Last epoch-30 dias: $last_epoch_30 \n";
	print "Last epoch-30 dias: $dt2 \n";
}
my $reg_ultimos_30=Statistics::Regression->new( "Lineal de Crecimiento de BD ultimos 30 dias", ["Intercep.", "Pendiente"]); 
for my $key ( keys %puntos ) {
    if ( $key > $last_epoch_30 ) {
	    $reg_ultimos_30->include( $puntos{$key}, [$cat, $key]);
    }
}
my @theta_30  = $reg_ultimos_30->theta();
my $slope30 = $theta_30[1];
if ( $DEBUG ) {
	sep();

	print "\nUltimos 30 dias\n";
	print "Intercep.: $theta_30[0] \n";
	print "Pendiente: $slope30 \n";

	print "Nro. de Variables    : ".$reg_ultimos_30->k()."\n";
	print "Nro. de Observaciones: ".$reg_ultimos_30->n()."\n";   
#print "R^2                  :". $reg_ultimos_30->rsq()."\n";
}
# Con los puntos del ultimos 7 dias s7 (slope)
my $last_epoch_7 = $last_epoch - ( 7 * 24 * 3600 );
my $dt7 = DateTime->new( year => 1970, month => 1, day => 1 );
my $formatter7 = DateTime::Format::Epoch->new(
                      epoch          => $dt7,
                      unit           => 'seconds',
                      type           => 'int',    
                      skip_leap_seconds => 1,
                      start_at       => 0,
                      local_epoch    => undef,
                  );
my $dt2_7 = $formatter7->parse_datetime( $last_epoch_7 );
if ( $DEBUG ) {
	print "\nLast epoch: $last_epoch\n";
	print "Last epoch-7 dias: $last_epoch_7 \n";
	print "Last epoch-7 dias: $dt2_7 \n";
}
my $reg_ultimos_7=Statistics::Regression->new( "Lineal de Crecimiento de BD ultimos 7 dias", ["Intercep.", "Pendiente"]); 
for my $key ( keys %puntos ) {
    if ( $key > $last_epoch_7 ) {
	    $reg_ultimos_7->include( $puntos{$key}, [$cat, $key]);
    }
}
my @theta_7  = $reg_ultimos_7->theta();

my $slope7 = $theta_7[1];
if ( $DEBUG ) {
	print "\nUltimos 7 dias\n";
	print "Intercep.: $theta_7[0] \n";
	print "Pendiente: $slope7\n";

	print "Nro. de Variables    : ".$reg_ultimos_7->k()."\n";
	print "Nro. de Observaciones: ".$reg_ultimos_7->n()."\n";   
	#print "R^2                  :". $reg_ultimos_7->rsq()."\n";

	sep();
}
# Con los puntos del ultimo dia s1 (slope)
my $last_epoch_1 = $last_epoch - ( 1 * 24 * 3600 );
my $dt1 = DateTime->new( year => 1970, month => 1, day => 1 );
my $formatter1 = DateTime::Format::Epoch->new(
                      epoch          => $dt1,
                      unit           => 'seconds',
                      type           => 'int',    
                      skip_leap_seconds => 1,
                      start_at       => 0,
                      local_epoch    => undef,
                  );
my $dt2_1 = $formatter1->parse_datetime( $last_epoch_1 );

if ( $DEBUG ) {
	print "\nLast epoch: $last_epoch\n";
	print "Last epoch-1 dias: $last_epoch_1 \n";
	print "Last epoch-1 dias: $dt2_1 \n";
}

my $reg_ultimos_1=Statistics::Regression->new( "Lineal de Crecimiento de BD ultimo dia", ["Intercep.", "Pendiente"]); 
for my $key ( keys %puntos ) {
    if ( $key > $last_epoch_1 ) {
	    $reg_ultimos_1->include( $puntos{$key}, [$cat, $key]);
    }
}
my @theta_1  = $reg_ultimos_1->theta();

my $slope1 = $theta_1[1];
if ( $DEBUG ) {
	print "\nUltimo 1 dia\n";
	print "Intercep.: $theta_1[0] \n";
	print "Pendiente: $slope1\n";

	print "Nro. de Variables    : ".$reg_ultimos_1->k()."\n";
	print "Nro. de Observaciones: ".$reg_ultimos_1->n()."\n";   
	#print "R^2                  :". $reg_ultimos_1->rsq()."\n";
}


print "Servidor: $serverid  BD: $db_name\n";
$dt_old =~ s/T/ /;
print "Numero de observaciones: ". $num_obs ."\tDato mas antiguo registrado: $dt_old\n"; # o en formato epoch:$last_epoch \n";
if ( $num_obs > 10 ) {
	print "Pendientes:\n";
	print "   Long-Term : ".sprintf("%.2f",$slopeLT)."\n";
	print "   Ultimos 30: ".sprintf("%.2f",$slope30)."\n";
	print "   Ultimos  7: ".sprintf("%.2f",$slope7)."\n";
	print "   Ultimo dia: ".sprintf("%.2f",$slope1)."\n";
}
else {
	return;
}

# Criterios de alarma
my $alarma1       = 0;
my $min_slope     = 0.01;   # Evitar revision de BD que no crecen (slope ~ 0)
my $alarm_message = '';

if ( $slope1 > $min_slope and $slope7 > $min_slope  and $slope1 > $slope7 * $pct_1  ) {
    $alarma1 = 1;
	$alarm_message .= "Crecimiento anomalo ultimo dia\t";
}

my $alarma7 = 0;
if ( $slope7 > $min_slope  and $slope30 > $min_slope  and $slope7 > $slope30 * $pct_7 ) {
    $alarma7 = 1;
	$alarm_message .= "Crecimiento anomalo ultima semana\t";
}

my $alarma30 = 0;
if ( $slope30 > $min_slope  and $slopeLT > $min_slope  and $slope30 > $slopeLT * $pct_30 ) {
    $alarma30 = 1;
	$alarm_message .= "Crecimiento anomalo ultimo mes\t";
}

# Avisar si hay alguna alarma
if ( $alarma1 or $alarma7 or $alarma30 ) {
    print "Enviando alarmas ..\n";
	print "$alarm_message\n";
	system("$alarm_script $serverid $db_name $alarm_message");
}

# Sin crecimiento en los ultimos 30 dias y con mas de 50 observaciones
if ( $last_epoch < $last_epoch_1 - (30 * 24 * 3600) and $num_obs > 50 and $slopeLT < 0.0001 ) {
	$alarm_message = "BD : $db_name en Servidor: $serverid no ha crecido desde $dt_old";
	print "Enviando alarmas ...\n";
	print "$alarm_message\n";
	system("$alarm_script $serverid $db_name $alarm_message");
}
sep();

sub sep {
    print "--------------------------------------------------------------------------\n";
}

