package apis

import (
	xpresource "github.com/crossplane/crossplane-runtime/v2/pkg/resource"
	"github.com/pkg/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

var s = runtime.NewScheme()

func BuildScheme(sb runtime.SchemeBuilder) error {
	return sb.AddToScheme(s)
}

func GetManagedResource(group, version, kind, listKind string) (xpresource.Managed, xpresource.ManagedList, error) {
	gv := schema.GroupVersion{Group: group, Version: version}
	m, err := s.New(gv.WithKind(kind))
	if err != nil {
		return nil, nil, errors.Wrapf(err, "cannot get managed resource of kind %q", gv.WithKind(kind))
	}
	l, err := s.New(gv.WithKind(listKind))
	if err != nil {
		return nil, nil, errors.Wrapf(err, "cannot get managed resource list of kind %q", gv.WithKind(listKind))
	}
	return m.(xpresource.Managed), l.(xpresource.ManagedList), nil
}
