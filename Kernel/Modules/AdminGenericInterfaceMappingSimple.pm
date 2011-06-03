# --
# Kernel/Modules/AdminGenericInterfaceMappingSimple.pm - provides a TransportHTTPSOAP view for admins
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: AdminGenericInterfaceMappingSimple.pm,v 1.2 2011-06-03 07:31:58 cg Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminGenericInterfaceMappingSimple;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.2 $) [1];

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::GenericInterface::Webservice;
use Kernel::System::Valid;
use YAML;

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    for (qw(ParamObject LayoutObject LogObject ConfigObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    # create addtional objects
    $Self->{ValidObject} = Kernel::System::Valid->new( %{$Self} );
    $Self->{WebserviceObject} =
        Kernel::System::GenericInterface::Webservice->new( %{$Self} );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $WebserviceID = $Self->{ParamObject}->GetParam( Param => 'WebserviceID' )
        || '';
    my $Operation = $Self->{ParamObject}->GetParam( Param => 'Operation' )
        || '';
    my $Invoker = $Self->{ParamObject}->GetParam( Param => 'Invoker' )
        || '';
    my $Direction = $Self->{ParamObject}->GetParam( Param => 'Direction' )
        || '';

    my $CommunicationType = IsStringWithData($Operation) ? 'Provider'  : 'Requester';
    my $ActionType        = IsStringWithData($Operation) ? 'Operation' : 'Invoker';
    my $Action = $Operation || $Invoker;

    # ------------------------------------------------------------ #
    # subaction Change: load webservice and show edit screen
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Add' || $Self->{Subaction} eq 'Change' ) {

        # check for WebserviceID
        if ( !$WebserviceID ) {
            return $Self->{LayoutObject}
                ->ErrorScreen( Message => "Need WebserviceID!", );
        }

        # get webserice configuration
        my $WebserviceData =
            $Self->{WebserviceObject}->WebserviceGet( ID => $WebserviceID );

        # check for valid webservice configuration
        if ( !IsHashRefWithData($WebserviceData) ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Could not get data for WebserviceID $WebserviceID",
            );
        }

        return $Self->_ShowEdit(
            %Param,
            WebserviceID      => $WebserviceID,
            WebserviceData    => $WebserviceData,
            Operation         => $Operation,
            Invoker           => $Invoker,
            Direction         => $Direction,
            CommunicationType => $CommunicationType,
            ActionType        => $ActionType,
            Action            => $Action,
            Subaction         => 'Change',
        );
    }

    # ------------------------------------------------------------ #
    # subaction ChangeAction: write config and return to overview
    # ------------------------------------------------------------ #
    #    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {
    else {

        # check for WebserviceID
        if ( !$WebserviceID ) {
            return $Self->{LayoutObject}
                ->ErrorScreen( Message => "Need WebserviceID!", );
        }

        # get webserice configuration
        my $WebserviceData =
            $Self->{WebserviceObject}->WebserviceGet( ID => $WebserviceID );

        # check for valid webservice configuration
        if ( !IsHashRefWithData($WebserviceData) ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Could not get data for WebserviceID $WebserviceID",
            );
        }

        # get parameter from web browser
        my $GetParam = $Self->_GetParams;

        my %NewMapping;

        # set default key
        $NewMapping{KeyMapDefault}->{MapType} = $GetParam->{DefaultKeyType};
        $NewMapping{KeyMapDefault}->{MapTo}   = $GetParam->{DefaultKeyMapTo};

        # set default value
        $NewMapping{ValueMapDefault}->{MapType} = $GetParam->{DefaultValueType};
        $NewMapping{ValueMapDefault}->{MapTo}   = $GetParam->{DefaultValueMapTo};

        for my $KeyCounter ( $GetParam->{KeyCounter} ) {
            $NewMapping{ $GetParam->{ 'KeyMapTypeStrg' . $KeyCounter } }
                ->{ $GetParam->{ 'KeyName' . $KeyCounter } }
                =
                $GetParam->{ 'KeyMapNew' . $KeyCounter };

            for my $ValueCounter ($KeyCounter) {
                $NewMapping{ValueMap}->{ $GetParam->{ 'KeyMapNew' . $KeyCounter } }->
                    { $GetParam->{ 'KeyMapTypeStrg' . $KeyCounter } }->
                    { $GetParam->{ 'KeyName' . $KeyCounter } } =
                    $GetParam->{ 'KeyMapNew' . $KeyCounter };
            }
        }

        #        # check required parameters
        #        my %Error;
        #        for my $ParamName (
        #            qw( NameSpace Encoding )
        #            )
        #        {
        #            if ( !$GetParam->{$ParamName} ) {
        #
        #                # add server error error class
        #                $Error{ $ParamName . 'ServerError' } = 'ServerError';
        #                $Error{ $ParamName . 'ServerErrorMessage' } =
        #                    'This field is required';
        #            }
        #        }

        #        # check if endpoind is required
        #        if ( $CommunicationType ne 'Provider' && !$GetParam->{Endpoint} ) {
        #
        #            # add server error error class
        #            $Error{EndpointServerError} = 'ServerError';
        #            $Error{EndpointServerErrorMessage} =
        #                'This field is required';
        #        }
        # set new mapping
        $WebserviceData->{Config}->{$CommunicationType}->{$ActionType}->{$Action}->{$Direction}
            ->{Config}
            = \%NewMapping;

        #        # if there is an error return to edit screen
        #        if ( IsHashRefWithData( \%Error ) ) {
        #            return $Self->_ShowEdit(
        #                %Error,
        #                %Param,
        #                WebserviceID      => $WebserviceID,
        #                WebserviceData    => $WebserviceData,
        #                CommunicationType => $CommunicationType,
        #                Action            => 'Change',
        #            );
        #        }

        # otherwise save configuration and return to overview screen
        my $Success = $Self->{WebserviceObject}->WebserviceUpdate(
            ID      => $WebserviceID,
            Name    => $WebserviceData->{Name},
            Config  => $WebserviceData->{Config},
            ValidID => $WebserviceData->{ValidID},
            UserID  => $Self->{UserID},
        );

        # get webserice configuration
        #        my $WebserviceData2 =
        #            $Self->{WebserviceObject}->WebserviceGet( ID => $WebserviceID );

        return $Self->_ShowEdit(
            %Param,
            WebserviceID      => $WebserviceID,
            WebserviceData    => $WebserviceData,
            Operation         => $Operation,
            Invoker           => $Invoker,
            Direction         => $Direction,
            CommunicationType => $CommunicationType,
            ActionType        => $ActionType,
            Action            => $Action,
            Subaction         => 'Change',
        );

#return;
#        return $Self->{LayoutObject}->Redirect(
#            OP =>
#                "Action=AdminGenericInterfaceWebservice;Subaction=Change;WebserviceID=$WebserviceID",
#        );
    }

}

sub _ShowEdit {
    my ( $Self, %Param ) = @_;

    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();

    my $MappingConfig = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->
        { $Param{ActionType} }->{ $Param{Action} }->{ $Param{Direction} }->{Config};
    $Param{WebserviceName} = $Param{WebserviceData}->{Name};
    $Param{Type}           = 'Mapping::Simple';

    # select object for keys
    $Param{DefaultKeyTypeStrg} = $Self->{LayoutObject}->BuildSelection(
        Data => [
            {
                Key   => 'Keep',
                Value => 'Keep (leave unchanged)',
            },
            {
                Key   => 'Ignore',
                Value => 'Ignore (drop key/value pair)',
            },
            {
                Key   => 'MapTo',
                Value => 'MapTo (use provided value as default)',
            },
        ],
        Name         => 'DefaultKeyType',
        Class        => 'DefaultType',
        PossibleNone => 1,
        Translate    => 0,
    );

    $Param{KeyMapTypeStrg} = $Self->{LayoutObject}->BuildSelection(
        Data => [
            {
                Key   => 'KeyMapExact',
                Value => 'Exact value(s)',
            },
            {
                Key   => 'KeyMapRegEx',
                Value => 'Regular expression',
            },
        ],
        Name         => 'KeyMapTypeStrg',
        PossibleNone => 1,
        Translate    => 0,
    );

    # select objects for values
    $Param{DefaultValueTypeStrg} = $Self->{LayoutObject}->BuildSelection(
        Data => [
            {
                Key   => 'Keep',
                Value => 'Keep (leave unchanged)',
            },
            {
                Key   => 'Ignore',
                Value => 'Ignore (drop Value/value pair)',
            },
            {
                Key   => 'MapTo',
                Value => 'MapTo (use provided value as default)',
            },
        ],
        Name         => 'DefaultValueType',
        Class        => 'DefaultType',
        PossibleNone => 1,
        Translate    => 0,
    );

    $Param{ValueMapTypeStrg} = $Self->{LayoutObject}->BuildSelection(
        Data => [
            {
                Key   => 'ValueMapExact',
                Value => 'Exact value(s)',
            },
            {
                Key   => 'ValueMapRegEx',
                Value => 'Regular expression',
            },
        ],
        Name         => 'ValueMapTypeStrg',
        PossibleNone => 1,
        Translate    => 0,
    );

   #    $Param{Endpoint}
   #        = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->{Transport}->{Config}
   #        ->{Endpoint};
   #    $Param{NameSpace}
   #        = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->{Transport}->{Config}
   #        ->{NameSpace};
   #    $Param{Encoding}
   #        = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->{Transport}->{Config}
   #        ->{Encoding};
   #    $Param{SOAPAction}
   #        = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->{Transport}->{Config}
   #        ->{SOAPAction};
   #    $Param{MaxLength}
   #        = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->{Transport}->{Config}
   #        ->{MaxLength};

    # check if endpoind is required
    #    if ( $Param{CommunicationType} ne 'Provider' ) {
    #        $Param{EndpointValidateRequired} = 'Validate_Required';
    #    }
    $Self->{LayoutObject}->Block(
        Name => 'KeyTemplate',
        Data => {
            Classes => 'KeyTemplate Hidden',
            %Param,
        },
    );
    $Self->{LayoutObject}->Block(
        Name => 'ValueTemplate',
        Data => { %Param, },
    );

    # add saved values

    $Self->{LayoutObject}->Block(
        Name => 'WebservicePathElement',
        Data => {
            Name => 'Web Services',
            Link => 'Action=AdminGenericInterfaceWebservice',
            Nav  => '',
        },
    );
    $Self->{LayoutObject}->Block(
        Name => 'WebservicePathElement',
        Data => {
            Name => $Param{WebserviceName},
            Link => 'Action=AdminGenericInterfaceWebservice;Subaction=' . $Param{Subaction}
                . ';WebserviceID=' . $Param{WebserviceID},
            Nav => '',
        },
    );

    $Self->{LayoutObject}->Block(
        Name => 'WebservicePathElement',
        Data => {
            Name => ' Transport ' . $Param{Type},
            Link => 'Action=AdminGenericInterfaceMappingSimple;Subaction=' . $Param{Subaction}
                . ';CommunicationType='
                . ';WebserviceID=' . $Param{WebserviceID},
            Nav => '',
        },
    );

    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminGenericInterfaceMappingSimple',
        Data         => { %Param, },
    );

    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}

sub _GetParams {
    my ( $Self, %Param ) = @_;

    my $GetParam;

    # get parameters from web browser
    for my $ParamName (
        qw(
        KeyCounter DefaultKeyType DefaultKeyMapTo DefaultValueType DefaultValueMapTo
        )
        )
    {
        $GetParam->{$ParamName} =
            $Self->{ParamObject}->GetParam( Param => $ParamName ) || '';
    }

    # get params for keys
    for my $KeyCounter ( $GetParam->{KeyCounter} ) {
        $GetParam->{ 'KeyMapTypeStrg' . $KeyCounter } =
            $Self->{ParamObject}->GetParam( Param => 'KeyMapTypeStrg' . $KeyCounter ) || '';

        $GetParam->{ 'KeyName' . $KeyCounter } =
            $Self->{ParamObject}->GetParam( Param => 'KeyName' . $KeyCounter ) || '';

        $GetParam->{ 'KeyMapNew' . $KeyCounter } =
            $Self->{ParamObject}->GetParam( Param => 'KeyMapNew' . $KeyCounter ) || '';

        $GetParam->{ 'ValueCounter' . $KeyCounter } =
            $Self->{ParamObject}->GetParam( Param => 'ValueCounter' . $KeyCounter ) || 0;

        # get params for keys
        for my $ValueCounter ( $GetParam->{ 'ValueCounter' . $KeyCounter } ) {
            $GetParam->{ 'ValueMapTypeStrg' . $KeyCounter . '_' . $ValueCounter } =
                $Self->{ParamObject}
                ->GetParam( Param => 'ValueMapTypeStrg' . $KeyCounter . '_' . $ValueCounter ) || '';

            $GetParam->{ 'ValueName' . $KeyCounter . '_' . $ValueCounter } =
                $Self->{ParamObject}
                ->GetParam( Param => 'ValueName' . $KeyCounter . '_' . $ValueCounter ) || '';

            $GetParam->{ 'ValueMapNew' . $KeyCounter . '_' . $ValueCounter } =
                $Self->{ParamObject}
                ->GetParam( Param => 'ValueMapNew' . $KeyCounter . '_' . $ValueCounter ) || '';
        }
    }

    return $GetParam;
}
1;
